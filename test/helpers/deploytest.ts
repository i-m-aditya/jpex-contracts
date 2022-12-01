import { BigNumber } from "bignumber.js";


export function getNumInUnits(amt: any, unit: any) {
  return new BigNumber(amt).multipliedBy(10 ** unit).toFixed(0);
}

export function getNumBackInUnits(amt: any, unit: any) {
  return (new BigNumber(amt.toString())).div(10 ** unit).toString()
}
