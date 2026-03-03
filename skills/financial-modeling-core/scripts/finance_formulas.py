from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List


def cost_of_equity(rf: float, beta: float, erp: float) -> float:
    return rf + beta * erp


def after_tax_cost_of_debt(kd: float, tax_rate: float) -> float:
    return kd * (1 - tax_rate)


def wacc(ke: float, kd_after_tax: float, weight_equity: float, weight_debt: float) -> float:
    return ke * weight_equity + kd_after_tax * weight_debt


def ufcf(ebit: float, tax_rate: float, da: float, capex: float, delta_nwc: float) -> float:
    nopat = ebit * (1 - tax_rate)
    return nopat + da - capex - delta_nwc


def discount_factor(rate: float, period: float) -> float:
    return 1 / ((1 + rate) ** period)


def pv(amount: float, rate: float, period: float) -> float:
    return amount * discount_factor(rate, period)


def terminal_value_perpetuity(next_year_ufcf: float, wacc_value: float, g: float) -> float:
    if g >= wacc_value:
        raise ValueError("Terminal growth g must be < WACC")
    return next_year_ufcf / (wacc_value - g)


@dataclass
class DcfResult:
    enterprise_value: float
    equity_value: float
    implied_price: float


def dcf_valuation(
    projected_ufcf: Iterable[float],
    wacc_value: float,
    terminal_growth: float,
    net_debt: float,
    diluted_shares: float,
    mid_year: bool = True,
) -> DcfResult:
    cashflows: List[float] = list(projected_ufcf)
    if len(cashflows) < 2:
        raise ValueError("Need at least 2 projected cashflows")

    pv_fcfs = 0.0
    for idx, cf in enumerate(cashflows, start=1):
        period = idx - 0.5 if mid_year else idx
        pv_fcfs += pv(cf, wacc_value, period)

    next_year_cf = cashflows[-1] * (1 + terminal_growth)
    tv = terminal_value_perpetuity(next_year_cf, wacc_value, terminal_growth)
    terminal_period = len(cashflows) - 0.5 if mid_year else len(cashflows)
    pv_tv = pv(tv, wacc_value, terminal_period)

    ev = pv_fcfs + pv_tv
    eq = ev - net_debt
    price = eq / diluted_shares
    return DcfResult(enterprise_value=ev, equity_value=eq, implied_price=price)


def ev(market_cap: float, total_debt: float, cash: float) -> float:
    return market_cap + total_debt - cash


def multiple_ev_revenue(ev_value: float, revenue: float) -> float:
    return ev_value / revenue


def multiple_ev_ebitda(ev_value: float, ebitda: float) -> float:
    return ev_value / ebitda


def median(values: List[float]) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        raise ValueError("Empty list")
    m = n // 2
    return (s[m - 1] + s[m]) / 2 if n % 2 == 0 else s[m]


if __name__ == "__main__":
    # quick smoke test
    ke = cost_of_equity(0.04, 1.1, 0.055)
    kd_at = after_tax_cost_of_debt(0.06, 0.2)
    w = wacc(ke, kd_at, 0.8, 0.2)
    r = dcf_valuation([100, 120, 140, 160, 180], w, 0.025, net_debt=50, diluted_shares=100)
    print(r)
