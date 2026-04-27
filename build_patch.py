import sys
import json
import urllib.request

def request(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read())

base = "http://127.0.0.1:2600"

def add_module(plugin, slug):
    print(f"Adding {plugin}/{slug}...")
    res = request("POST", f"{base}/modules/add", {"plugin": plugin, "slug": slug})
    if res["status"] == "ok":
        return res["data"]["id"]
    else:
        print(f"Error adding {slug}: {res}")
        sys.exit(1)

def connect(out_id, out_port, in_id, in_port):
    print(f"Connecting {out_id}:{out_port} -> {in_id}:{in_port}...")
    request("POST", f"{base}/cables", {
        "outputModuleId": out_id,
        "outputId": out_port,
        "inputModuleId": in_id,
        "inputId": in_port
    })

def set_param(mod_id, param_id, value):
    request("POST", f"{base}/modules/{mod_id}/params", {
        "params": [{"id": param_id, "value": value}]
    })

# 1. Add modules (auto-positioned to the right)
vco_id = add_module("Fundamental", "VCO")
vcf_id = add_module("Fundamental", "VCF")
vca_id = add_module("Fundamental", "VCA")
audio_id = add_module("Core", "AudioInterface2")

# 2. Connect
# VCO SAW (out 2) -> VCF IN (in 0)
connect(vco_id, 2, vcf_id, 0)
# VCF LPF (out 0) -> VCA IN (in 0)
connect(vcf_id, 0, vca_id, 0)
# VCA OUT (out 0) -> Audio L (in 0)
connect(vca_id, 0, audio_id, 0)
# VCA OUT (out 0) -> Audio R (in 1)
connect(vca_id, 0, audio_id, 1)

# 3. Set parameters
# VCF: FREQ=0.5, RES=0.3
set_param(vcf_id, 0, 0.5)
set_param(vcf_id, 1, 0.3)
# VCA: LEVEL=1.0
set_param(vca_id, 0, 1.0)

print("Patch built successfully!")
