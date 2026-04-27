# Example 01 — VCO → Audio Out

Minimal patch: a single oscillator routed to the audio interface.
Good as a first test to confirm the server is working end-to-end.

## Steps

### 1. Confirm server is alive

```bash
python skills/vcvrack_client.py status
```

### 2. Find the correct slugs

```bash
python skills/vcvrack_client.py library VCV
```

Look for `VCO-1` and `AudioInterface2` in the output.

### 3. Add modules

```bash
python skills/vcvrack_client.py add VCV VCO-1
# → note returned id, e.g. 42

python skills/vcvrack_client.py add VCV AudioInterface2
# → note returned id, e.g. 99
```

### 4. Manually configure audio

**Crucial Step:** Since the MCP server can't choose your hardware, you **must** manually click on the `AudioInterface2` module in the Rack window and select your **Audio Driver** and **Device**.

### 5. Inspect ports

```bash
python skills/vcvrack_client.py module 42
# outputs: 0=SIN, 1=TRI, 2=SAW, 3=SQR, 4=VCO (mix)

python skills/vcvrack_client.py module 99
# inputs: 0=L, 1=R
```

### 6. Inspect params before changing anything

```bash
python skills/vcvrack_client.py params 42
```

Confirm that param `0` is the oscillator frequency control and use the reported
`min`, `max`, and `displayValue` fields as the source of truth.

### 7. Set VCO frequency

```bash
# For VCV VCO-1, 0.0 is typically A4 (440 Hz), but verify in the params output first.
python skills/vcvrack_client.py set-param 42 0 0.0
```

### 8. Re-read params to confirm the change

```bash
python skills/vcvrack_client.py params 42
```

### 9. Connect VCO SIN output → Audio L input

```bash
python skills/vcvrack_client.py connect 42 0 99 0
```

### 10. (Optional) Also connect to R for stereo

```bash
python skills/vcvrack_client.py connect 42 0 99 1
```

### 11. Save

```bash
python skills/vcvrack_client.py save ~/Documents/Rack2/patches/01_vco_audio.vcv
```

## Troubleshooting

- If `set-param` times out, make sure Rack is responsive and the MCP Server LED is still green.
- Retry with a single param write exactly like above, then re-run `params 42` before making more changes.

## Result

A sine wave at A4 playing through the audio interface.
