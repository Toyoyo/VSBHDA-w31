#!/usr/bin/env python3
"""Test sounds for test/win311.sh and test/install.sh:
T440.WAV (440 Hz, 16-bit stereo 22050 Hz, 2 s), T880.WAV (880 Hz, 8-bit
mono 11025 Hz, 1 s), SCALE.MID (C major scale on channel 1, then a snare on
channel 10), SCALE13.MID (the scale on channel 13).
  mksounds.py outdir"""
import math, struct, sys, wave

def tone(name, freq, rate, seconds, width, channels):
    w = wave.open(name, 'wb')
    w.setnchannels(channels); w.setsampwidth(width); w.setframerate(rate)
    frames = bytearray()
    for i in range(rate * seconds):
        s = math.sin(2 * math.pi * freq * i / rate)
        if width == 2:
            frames += struct.pack('<h', int(16383.5 * s)) * channels
        else:
            frames += bytes([int(128 + 63.5 * s)]) * channels
    w.writeframes(bytes(frames)); w.close()

def midi(name, ch, drum):
    trk = bytes([0, 0xC0 | ch, 0])                          # program 0
    for n in (60, 62, 64, 65, 67, 69, 71, 72):
        trk += bytes([0, 0x90 | ch, n, 100, 0x81, 0x70, 0x80 | ch, n, 0])
    if drum:
        trk += bytes([0, 0x99, 38, 120, 0x81, 0x70, 0x89, 38, 0])
    trk += bytes([0, 0xFF, 0x2F, 0])
    open(name, 'wb').write(b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480) +
                           b'MTrk' + struct.pack('>I', len(trk)) + trk)

out = sys.argv[1] if len(sys.argv) > 1 else '.'
tone(out + '/T440.WAV', 440, 22050, 2, 2, 2)
tone(out + '/T880.WAV', 880, 11025, 1, 1, 1)
midi(out + '/SCALE.MID', 0, True)
midi(out + '/SCALE13.MID', 12, False)
