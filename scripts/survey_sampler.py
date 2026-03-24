#!/usr/bin/env python3
"""
Minimal sample-size helper for comparing two proportions (A/B style).

Uses a normal approximation to the binary proportion difference. This is a
planning aid, not a substitute for proper study design or professional
statistics review for regulated contexts.

Usage:
  python3 scripts/survey_sampler.py --p1 0.40 --p2 0.50 --alpha 0.05 --power 0.8

Dependencies: none (stdlib only).
"""

from __future__ import annotations

import argparse
import math
import sys


def norm_ppf(p: float) -> float:
    """Inverse CDF for standard normal (Acklam's approximation)."""
    if not 0.0 < p < 1.0:
        raise ValueError("p must be in (0,1)")
    # Coefficients for rational approximation of the quantile function
    a = (
        -3.969683028665376e01,
        2.209460984245205e02,
        -2.759285104469687e02,
        1.383577518672690e02,
        -3.066479806614716e01,
        2.506628277459239e00,
    )
    b = (
        -5.447609879897406e01,
        1.615858368580409e02,
        -1.556989798598866e02,
        6.680131188771972e01,
        -1.328068155288572e01,
    )
    c = (
        -7.784894002430293e-03,
        -3.223964580911365e-01,
        -2.400758277161838e00,
        -2.549732539343734e00,
        4.374664141464968e00,
        2.938163982698783e00,
    )
    d = (
        7.784695709041462e-03,
        3.224671290700398e-01,
        2.445134137142996e00,
        3.754408661907416e00,
    )

    plow = 0.02425
    phigh = 1 - plow
    if p < plow:
        q = math.sqrt(-2 * math.log(p))
        return (
            (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
            / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        )
    if phigh < p:
        q = math.sqrt(-2 * math.log(1 - p))
        return -(
            (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
            / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        )
    q = p - 0.5
    r = q * q
    return (
        (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5])
        * q
        / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    )


def two_proportion_n(
    p1: float,
    p2: float,
    alpha: float = 0.05,
    power: float = 0.8,
    ratio: float = 1.0,
) -> float:
    """Returns approximate n per group for two-sided test of p1 vs p2."""
    if not (0 < p1 < 1 and 0 < p2 < 1):
        raise ValueError("p1 and p2 must be strictly between 0 and 1")
    z_alpha = norm_ppf(1 - alpha / 2)
    z_beta = norm_ppf(power)
    p_bar = (p1 + ratio * p2) / (1 + ratio)
    num = (
        z_alpha * math.sqrt(p_bar * (1 - p_bar) * (1 + 1 / ratio))
        + z_beta * math.sqrt(p1 * (1 - p1) + p2 * (1 - p2) / ratio)
    ) ** 2
    den = (p1 - p2) ** 2
    return num / den


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--p1", type=float, required=True, help="Baseline proportion")
    parser.add_argument("--p2", type=float, required=True, help="Alternative proportion")
    parser.add_argument("--alpha", type=float, default=0.05, help="Two-sided alpha")
    parser.add_argument("--power", type=float, default=0.8, help="Desired power")
    parser.add_argument(
        "--ratio",
        type=float,
        default=1.0,
        help="n2/n1 allocation ratio (default 1.0 equal groups)",
    )
    args = parser.parse_args()

    try:
        n = two_proportion_n(args.p1, args.p2, args.alpha, args.power, args.ratio)
    except ValueError as exc:
        print(f"Invalid input: {exc}", file=sys.stderr)
        return 1

    n_per = math.ceil(n)
    print("Two-proportion difference (normal approximation, two-sided)")
    print(f"  p1={args.p1}, p2={args.p2}, alpha={args.alpha}, power={args.power}, ratio={args.ratio}")
    print(f"  Approx n per group: {n_per}")
    print(f"  Approx total N: {n_per + math.ceil(n_per * args.ratio)}")
    print("Note: this is a planning estimate; consult a statistician for regulated work.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
