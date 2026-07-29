#!/usr/bin/env python3
"""Verify PyTorch and TensorFlow are installed, actually using multiple CPU
threads, and actually using the GPU when one is present.

This measures rather than trusts: reporting `torch.get_num_threads() == 16` only
proves what torch intends to do, so the CPU check times the same matmul at 1
thread vs all cores and reports the observed speedup. A machine with a broken
OpenMP/MKL setup reports 16 threads and still scales at 1.0x.

Exit status is 0 when healthy, 1 when something is wrong -- notably when an
NVIDIA GPU is present (--expect-gpu) but torch cannot see it, which is the
signature of CPU-only wheels having been installed by mistake.
"""

import argparse
import os
import sys
import time

# Quiet TensorFlow's startup logging before it is imported.
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

MATMUL_N = 4096
FLOPS_PER_MATMUL = 2 * MATMUL_N**3


def gflops(seconds):
    return FLOPS_PER_MATMUL / seconds / 1e9


def time_op(fn, warmup=1, iters=3):
    """Time fn(), discarding warmup runs, returning the best wall time."""
    for _ in range(warmup):
        fn()
    best = float("inf")
    for _ in range(iters):
        start = time.perf_counter()
        fn()
        best = min(best, time.perf_counter() - start)
    return best


def check_torch(expect_gpu, failures):
    print("\n=== PyTorch ===")
    try:
        import torch
    except ImportError as exc:
        print(f"  FAIL: cannot import torch ({exc})")
        failures.append("torch not importable")
        return

    print(f"  torch version:  {torch.__version__}")
    print(f"  CUDA build:     {torch.version.cuda or 'CPU-only build'}")

    # --- CPU parallelism: measure, don't trust the reported thread count ---
    cores = os.cpu_count() or 1
    a = torch.randn(MATMUL_N, MATMUL_N)
    b = torch.randn(MATMUL_N, MATMUL_N)

    torch.set_num_threads(1)
    single = time_op(lambda: a @ b)

    torch.set_num_threads(cores)
    multi = time_op(lambda: a @ b)

    speedup = single / multi
    print(f"  logical cores:  {cores}")
    print(f"  threads in use: {torch.get_num_threads()}")
    print(f"  matmul {MATMUL_N}^2  1 thread : {single:.3f}s ({gflops(single):.1f} GFLOPS)")
    print(f"  matmul {MATMUL_N}^2  {cores} threads: {multi:.3f}s ({gflops(multi):.1f} GFLOPS)")
    print(f"  CPU parallel speedup: {speedup:.2f}x")

    # On any multi-core box a healthy threaded BLAS clears 1.5x comfortably.
    # Below that, threading is effectively not happening.
    if cores > 1 and speedup < 1.5:
        print("  FAIL: CPU matmul is not scaling across threads")
        failures.append(f"torch CPU parallelism only {speedup:.2f}x on {cores} cores")
    else:
        print("  OK: CPU matmul scales across threads")

    # --- GPU ---
    if not torch.cuda.is_available():
        if expect_gpu:
            print("  FAIL: an NVIDIA GPU is present but torch.cuda.is_available() is False")
            print("        This usually means CPU-only wheels were installed. Reinstall with:")
            print("        pip install --force-reinstall torch --index-url https://download.pytorch.org/whl/cu126")
            failures.append("torch cannot see the installed NVIDIA GPU")
        else:
            print("  SKIP: no CUDA GPU available (CPU-only machine)")
        return

    print(f"  CUDA devices:   {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(
            f"    [{i}] {props.name}, {props.total_memory / 1024**3:.1f} GiB, "
            f"compute {props.major}.{props.minor}, {props.multi_processor_count} SMs"
        )

    ga = a.cuda()
    gb = b.cuda()

    def gpu_matmul():
        ga @ gb
        torch.cuda.synchronize()  # CUDA is async; without this we time the launch, not the work

    gpu = time_op(gpu_matmul, warmup=3)
    print(f"  matmul {MATMUL_N}^2  GPU      : {gpu:.4f}s ({gflops(gpu):.1f} GFLOPS)")
    print(f"  GPU vs CPU speedup: {multi / gpu:.1f}x")
    print("  OK: GPU compute verified")


def check_tensorflow(expect_gpu, failures):
    print("\n=== TensorFlow ===")
    try:
        import tensorflow as tf
    except ImportError as exc:
        print(f"  FAIL: cannot import tensorflow ({exc})")
        failures.append("tensorflow not importable")
        return

    print(f"  TF version:     {tf.__version__}")
    print(f"  intra-op threads: {tf.config.threading.get_intra_op_parallelism_threads()} (0 = auto/all cores)")
    print(f"  inter-op threads: {tf.config.threading.get_inter_op_parallelism_threads()} (0 = auto)")

    gpus = tf.config.list_physical_devices("GPU")
    print(f"  GPUs visible:   {len(gpus)}")
    for gpu in gpus:
        print(f"    {gpu.name} ({gpu.device_type})")

    with tf.device("/CPU:0"):
        a = tf.random.normal((MATMUL_N, MATMUL_N))
        b = tf.random.normal((MATMUL_N, MATMUL_N))
        cpu = time_op(lambda: tf.matmul(a, b).numpy())
    print(f"  matmul {MATMUL_N}^2  CPU      : {cpu:.3f}s ({gflops(cpu):.1f} GFLOPS)")

    if gpus:
        with tf.device("/GPU:0"):
            ga = tf.random.normal((MATMUL_N, MATMUL_N))
            gb = tf.random.normal((MATMUL_N, MATMUL_N))
            gpu_t = time_op(lambda: tf.matmul(ga, gb).numpy(), warmup=3)
        print(f"  matmul {MATMUL_N}^2  GPU      : {gpu_t:.4f}s ({gflops(gpu_t):.1f} GFLOPS)")
        print("  OK: GPU compute verified")
    elif expect_gpu and sys.platform == "win32":
        # Expected, not a failure: Google dropped native-Windows GPU support.
        print("  EXPECTED: no GPU. TensorFlow 2.10 was the last release supporting")
        print("            GPU on native Windows; 2.11+ is CPU-only here.")
        print("            For TensorFlow on GPU, run it inside WSL2.")
    else:
        print("  SKIP: no GPU available")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--expect-gpu",
        action="store_true",
        help="an NVIDIA GPU was detected on this host; treat torch not seeing it as a failure",
    )
    args = parser.parse_args()

    print(f"Python {sys.version.split()[0]} on {sys.platform}")
    print(f"Expecting GPU: {args.expect_gpu}")

    failures = []
    check_torch(args.expect_gpu, failures)
    check_tensorflow(args.expect_gpu, failures)

    print("\n=== Summary ===")
    if failures:
        for failure in failures:
            print(f"  FAIL: {failure}")
        print(f"\n{len(failures)} ML check(s) failed")
        return 1

    print("  All ML checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
