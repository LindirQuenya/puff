#!/usr/bin/env python3
import json
import sys

import numpy as np
import matplotlib.pyplot as plt

def dB(x):
    return 20*np.log10(np.abs(x))

def degrees(x):
    return np.degrees(np.angle(x))

def loadJson(fname):
    with open(fname, "r") as f:
        elements = json.load(f).items()
        freq = np.array([x[0] for x in elements], dtype=np.float64)
        sortind = np.argsort(freq)
        data = np.array([x[1] for x in elements])[sortind]
    # [Re, Im] to complex conversion
    s = data[:,:,:,0] + 1j*data[:,:,:,1]
    sparams = np.array([[s[:,i,j] for j in range(4)] for i in range(4)])
    return freq[sortind], sparams

def main():
    if len(sys.argv) != 2:
        print("Please provide exactly one argument, the json file to plot.")
        exit(0)

    freq, sparams = loadJson(sys.argv[1])
    for i in range(4):
        fig, axs = plt.subplots(2)
        for j in range(4):
            axs[0].plot(freq/1e9, dB(sparams[i][j]), label=r"$|s_{"+f"{i+1}{j+1}"+r"}|$")
            axs[1].plot(freq/1e9, degrees(sparams[i][j]), label=r"$\angle s_{"+f"{i+1}{j+1}"+r"}$")
        axs[0].legend()
        axs[0].set_ylabel('Magnitude (dB)')
        axs[1].set_ylabel('Phase (°)')
        axs[1].set_xlabel('Frequency (GHz)')
        axs[0].set_ylim([-40, 0])
        axs[0].grid()
        axs[1].grid()
    plt.show()

if __name__ == '__main__':
    main()
