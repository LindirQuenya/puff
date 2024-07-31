#!/usr/bin/env python3
import json
import sys

import numpy as np
import matplotlib.pyplot as plt

def dB(x):
    return 20*np.log10(np.abs(x))

def loadJson(fname):
    with open(fname, "r") as f:
        elements = json.load(f).items()
        freq = np.array([x[0] for x in elements], dtype=np.float64)
        sortind = np.argsort(freq)
        data = np.array([x[1] for x in elements])[sortind]
    # [Re, Im] to complex conversion
    s = data[:,:,:,0] + 1j*data[:,:,:,1]
    s11 = s[:,0,0]
    s12 = s[:,0,1]
    s21 = s[:,1,0]
    s22 = s[:,1,1]
    return freq[sortind], s11, s12, s21, s22

def main():
    if len(sys.argv) != 2:
        print("Please provide exactly one argument, the json file to plot.")
        exit(0)

    freq, s11, s12, s21, s22 = loadJson(sys.argv[1])

    plt.plot(freq/1e9, dB(s11), label=r"$|s_{11}|$")
    plt.plot(freq/1e9, dB(s12), label=r"$|s_{12}|$")
    plt.plot(freq/1e9, dB(s21), label=r"$|s_{21}|$")
    plt.plot(freq/1e9, dB(s22), label=r"$|s_{22}|$")

    plt.legend()
    plt.ylabel('Magnitude (dB)')
    plt.xlabel('Frequency (GHz)')
    plt.grid()

    plt.show()

if __name__ == '__main__':
    main()
