# Example 02 — VCO → VCF → VCA → Audio

Classic subtractive synthesis voice: oscillator through a filter and amplifier.

## Signal Chain

```text
VCO-1 (SAW) → VCF (low-pass) → VCA → AudioInterface2
```

## Steps

### 1. Discover slugs

```bash
python skills/vcvrack_client.py library VCV
```

Confirm `VCO-1`, `VCF`, `VCA`, `AudioInterface2` are present.

### 2. Add all modules

```bash
python skills/vcvrack_client.py add VCV VCO-1
# → id: 10

python skills/vcvrack_client.py add VCV VCF
# → id: 11

python skills/vcvrack_client.py add VCV VCA
# → id: 12

python skills/vcvrack_client.py add VCV AudioInterface2
# → id: 13
```

### 3. Inspect ports on each module

```bash
python skills/vcvrack_client.py module 10
# VCO-1 outputs: 0=SIN, 1=TRI, 2=SAW, 3=SQR

python skills/vcvrack_client.py module 11
# VCF  inputs:  0=IN, 1=FREQ(CV), 2=RES(CV)
# VCF  outputs: 0=LPF, 1=HPF

python skills/vcvrack_client.py module 12
# VCA  inputs:  0=IN, 1=CV
# VCA  outputs: 0=OUT

python skills/vcvrack_client.py module 13
# Audio inputs: 0=L, 1=R
```

### 4. Inspect params before setting them

```bash
python skills/vcvrack_client.py params 10
python skills/vcvrack_client.py params 11
python skills/vcvrack_client.py params 12
```

Use the returned `displayValue`, `min`, `max`, and optional `options` fields as
the source of truth. The values below are good starting points for the VCV
modules shown here, but verify them against the live param metadata before
writing.

### 5. Set parameters in small batches

```bash
# VCO: FREQ=0 (often A4), but confirm with `params 10` first
python skills/vcvrack_client.py set-param 10 0 0.0

# VCF: set cutoff first, then resonance
python skills/vcvrack_client.py set-param 11 0 0.5
python skills/vcvrack_client.py params 11

# VCF: add a little resonance
python skills/vcvrack_client.py set-param 11 1 0.3

# VCA: LEVEL (param 0) = 1.0 (full open)
python skills/vcvrack_client.py set-param 12 0 1.0
```

### 6. Re-read params to verify the settings

```bash
python skills/vcvrack_client.py params 10
python skills/vcvrack_client.py params 11
python skills/vcvrack_client.py params 12
```

### 7. Wire the signal chain

```bash
# VCO SAW (out 2) → VCF IN (in 0)
python skills/vcvrack_client.py connect 10 2 11 0

# VCF LPF (out 0) → VCA IN (in 0)
python skills/vcvrack_client.py connect 11 0 12 0

# VCA OUT (out 0) → Audio L (in 0)
python skills/vcvrack_client.py connect 12 0 13 0

# VCA OUT (out 0) → Audio R (in 1)
python skills/vcvrack_client.py connect 12 0 13 1
```

### 8. Save

```bash
python skills/vcvrack_client.py save ~/Documents/Rack2/patches/02_subtractive_voice.vcv
```

## Troubleshooting

- If a param write times out, retry with just one `{id, value}` change and confirm Rack is not blocked by a modal or menu.
- If the sound is too quiet or absent, re-check the cable routing with `module <id>` and make sure the Audio Interface is configured manually in Rack.

## Result

A filtered sawtooth wave through the audio interface.
Adjust VCF cutoff (param 0 on module 11) to open/close the filter.
