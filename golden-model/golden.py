import numpy as np
import torch
import argparse

parser = argparse.ArgumentParser()

parser.add_argument("--fpformat"            ,   type = str,     default = "BFLOAT16"    )
parser.add_argument("--a_fraction"          ,   type = int,     default = 14            )
parser.add_argument("--coefficient_fraction",   type = int,     default = 4             )
parser.add_argument("--constant_fraction"   ,   type = int,     default = 7             )
parser.add_argument("--mul_surplus_bits"    ,   type = int,     default = 1             )
parser.add_argument("--not_surplus_bits"    ,   type = int,     default = 0             )
parser.add_argument("--n_inputs"            ,   type = int,     default = 100          )
parser.add_argument("--alpha"               ,   type = float,   default = 0.218750000   )
parser.add_argument("--beta"                ,   type = float,   default = 0.410156250   )
parser.add_argument("--gamma1"              ,   type = float,   default = 2.835937500   )
parser.add_argument("--gamma2"              ,   type = float,   default = 2.167968750   )

args = parser.parse_args()

fpformat = args.fpformat

match fpformat:
    case "FLOAT32":
        mantissa_bits = 23
        exponent_bits = 8
        dtype = torch.float32
        flttype = np.float32
        inttype = np.uint32

    case "FLOAT16":
        mantissa_bits = 10
        exponent_bits = 5
        dtype = torch.float16
        flttype = np.float16
        inttype = np.uint16

    case "BFLOAT16":
        mantissa_bits = 7
        exponent_bits = 8
        dtype = torch.bfloat16
        flttype = np.float32
        inttype = np.uint32

    case _:
        raise ValueError(f"Unsupported type \"{fpformat}\"")

max_r = 2 ** (exponent_bits - 2) * 1.5
min_r = -max_r

vect = torch.empty(args.n_inputs, dtype = dtype).uniform_(min_r, max_r)

if (vect.dtype == torch.bfloat16):
    intvect = np.frombuffer(vect.float().numpy(), dtype = inttype) >> 16
else:
    intvect = np.frombuffer(vect.numpy(), dtype = inttype)

sign = intvect >> (mantissa_bits + exponent_bits)
mantissa = np.bitwise_and(intvect, 2 ** mantissa_bits - 1).astype(np.int64)
exponent = np.bitwise_and(intvect >> mantissa_bits, 2 ** exponent_bits - 1)
bias = 2 ** (exponent_bits - 1) - 1

a = np.round(1 / np.log(2) * 2 ** args.a_fraction).astype(np.int64)

mant = 2 ** mantissa_bits + mantissa

shm = np.where(exponent >= bias, (mant * a) << (exponent - bias), (mant * a) >> (bias - exponent))
shm = (shm >> args.a_fraction) + np.bitwise_and(shm >> (args.a_fraction - 1), 0b1)
shm = np.where(sign == 1, -shm, shm)

nm = np.bitwise_and(shm, 2 ** mantissa_bits - 1)
ne = (shm >> mantissa_bits) + bias

int_sch = (ne << mantissa_bits) + nm

if (dtype == torch.bfloat16):
    int_sch = int_sch << 16

exp_sch = np.frombuffer(int_sch.astype(inttype), flttype)



alpha = np.round(args.alpha * 2 ** args.coefficient_fraction).astype(np.uint64)
beta = np.round(args.beta * 2 ** args.coefficient_fraction).astype(np.uint64)

sum_fraction = max(mantissa_bits, args.constant_fraction)

gamma_1 = np.round(args.gamma1 * 2 ** args.constant_fraction).astype(np.int64) * 2 ** (sum_fraction - args.constant_fraction)
gamma_2 = np.round(args.gamma2 * 2 ** args.constant_fraction).astype(np.int64) * 2 ** (sum_fraction - args.constant_fraction)

if (dtype == torch.bfloat16):
    mant_add = np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype) >> 16, 2 ** mantissa_bits - 1).astype(np.int64) * 2 ** (sum_fraction - mantissa_bits)
    res_add_1 = np.where(mant_add < 2 ** (sum_fraction - 1), mant_add + gamma_1 , mant_add + gamma_2)
    
    mant_mul = np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype) >> 16, 2 ** mantissa_bits - 1).astype(np.int64) * 2 ** (args.mul_surplus_bits)
    res_mul_1 = np.where(mant_mul < 2 ** (args.mul_surplus_bits + mantissa_bits - 1), mant_mul * alpha, (beta * (2 ** (args.mul_surplus_bits + mantissa_bits) - mant_mul - 1)))
else:
    mant_add = np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype), 2 ** mantissa_bits - 1).astype(np.int64) * 2 ** (sum_fraction - mantissa_bits)
    res_add_1 = np.where(mant_add < 2 ** (sum_fraction - 1), mant_add + gamma_1 , mant_add + gamma_2)
    
    mant_mul = np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype), 2 ** mantissa_bits - 1).astype(np.int64) * 2 ** (args.mul_surplus_bits)
    res_mul_1 = np.where(mant_mul < 2 ** (args.mul_surplus_bits + mantissa_bits - 1), mant_mul * alpha, (beta * (2 ** (args.mul_surplus_bits + mantissa_bits) - mant_mul - 1)))

res_mul_2 = (res_mul_1 * res_add_1) >> (sum_fraction + args.coefficient_fraction + args.mul_surplus_bits - args.not_surplus_bits)

res_int = np.where(mant_add < 2 ** (sum_fraction - 1), res_mul_2, 2 ** (mantissa_bits + args.not_surplus_bits) - res_mul_2 - 1) >> args.not_surplus_bits

if (dtype == torch.bfloat16):
    res = np.frombuffer((np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype), 0xFF800000) + (res_int << 16)).astype(inttype), dtype = flttype)
    res = np.where(ne.astype(np.uint32) >= (2 ** exponent_bits - 1), np.where(sign == 0, float("inf"), 0), res).astype(flttype)
else:
    res = np.frombuffer((np.bitwise_and(np.frombuffer(exp_sch, dtype = inttype), np.bitwise_and(2 ** (mantissa_bits + exponent_bits + 1) - 1, 2 ** mantissa_bits - 1)) + res_int).astype(inttype), dtype = flttype)
    res = np.where(ne.astype(np.uint32) >= (2 ** exponent_bits - 1), np.where(sign == 0, float("inf"), 0), res).astype(flttype)

np.savetxt("input.txt", intvect, fmt = f"0x%0{(mantissa_bits + exponent_bits + 1) / 4}X")

if (dtype == torch.bfloat16):
    np.savetxt("result.txt", np.frombuffer(res, dtype = inttype) >> 16, fmt = f"0x%0{(mantissa_bits + exponent_bits + 1) / 4}X")
else:
    np.savetxt("result.txt", np.frombuffer(res, dtype = inttype), fmt = f"0x%0{(mantissa_bits + exponent_bits + 1) / 4}X")