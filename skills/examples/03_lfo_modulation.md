# Example 03 — LFO Modulating VCF Cutoff

Extends example 02 by adding an LFO that sweeps the filter cutoff automatically,
creating a classic auto-wah / filter-sweep effect.

## Signal Chain

```text
VCO-1 (SAW) → VCF (low-pass) → VCA → AudioInterface2
                 ↑
              LFO (SIN CV)
```

## Steps

### 1. Build the base voice first

Follow **example 02** to set up VCO → VCF → VCA → Audio.
Note the module IDs — this example assumes:

| Module | ID |
| ------ | -- |
| VCO-1  | 10 |
| VCF    | 11 |
| VCA    | 12 |
| Audio  | 13 |

### 2. Find the LFO slug

```bash
python skills/vcvrack_client.py library VCV
# look for "LFO-1" or "LFO-2"
```

### 3. Add the LFO

```bash
python skills/vcvrack_client.py add VCV LFO-1
# → id: 20
```

### 4. Inspect LFO ports and params

```bash
python skills/vcvrack_client.py module 20
# outputs: 0=SIN, 1=TRI, 2=SAW, 3=SQR, 4=ENV
# params:  0=FREQ (rate), 1=FM, 2=PW, 3=OFFSET, 4=GAIN

python skills/vcvrack_client.py params 20
```

### 5. Set LFO rate

Use the live `params 20` output as the source of truth. For `LFO-1`, a value
around `-2.0` is usually a slow sweep, but confirm the displayed value first.

```bash
# FREQ param (id 0): negative values are slower, positive are faster
python skills/vcvrack_client.py set-param 20 0 -2.0
```

### 6. Re-read the LFO params to confirm

```bash
python skills/vcvrack_client.py params 20
```

### 7. Connect LFO SIN → VCF FREQ CV input

```bash
# LFO SIN output (out 0) → VCF FREQ CV input (in 1)
python skills/vcvrack_client.py connect 20 0 11 1
```

### 8. Verify the patch

```bash
python skills/vcvrack_client.py cables
# should show 5 cables: VCO→VCF, VCF→VCA, VCA→AudioL, VCA→AudioR, LFO→VCF
```

### 9. Tweak — adjust sweep depth via VCF cutoff baseline

```bash
# Re-check the VCF params first so you are not guessing the cutoff range
python skills/vcvrack_client.py params 11

# Set VCF cutoff baseline to mid-range so LFO swings both ways
python skills/vcvrack_client.py set-param 11 0 0.5
```

### 10. Confirm the VCF update

```bash
python skills/vcvrack_client.py params 11
```

### 11. Save

```bash
python skills/vcvrack_client.py save ~/Documents/Rack2/patches/03_lfo_filter_sweep.vcv
```

## Result

The filter cutoff sweeps up and down at ~0.5 Hz, creating a rhythmic
filter-sweep effect. Increase LFO FREQ (param 0 on module 20) to speed up
the sweep, or decrease it for a slower, deeper movement.

## Troubleshooting

- If the sweep is too subtle, inspect the LFO and VCF params again before changing gain, offset, or cutoff.
- If `set-param` times out, make sure Rack is responsive and retry with one write at a time.
