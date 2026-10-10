#!/usr/bin/env python3
"""Faux moteurs de reconnaissance et de langage, pour la recette.

Ils parlent exactement l'API des vrais — whisper-server (whisper.cpp) et
llama-server (llama.cpp) — et vérifient la forme de chaque requête : un champ
mal nommé, que le vrai serveur rejetterait, est rejeté ici aussi. Ce qu'ils
répondent, en revanche, est écrit d'avance, pour que la recette mesure le code
de l'interface et non l'humeur d'un modèle.

    fake_servers.py serve --asr-port 18178 --llm-port 18179 \\
                          --transcripts "salut agoojiye|merci"
    fake_servers.py wav sortie.wav 3        # trois « phrases » synthétiques

Bibliothèque standard seulement : la recette ne doit rien installer.
"""

import json
import math
import random
import struct
import sys
import threading
import time
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


# ---------------------------------------------------------------- whisper ----
class Asr(BaseHTTPRequestHandler):
    transcripts = []
    lock = threading.Lock()

    def log_message(self, *args):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._send(200, {"status": "ok"}) if self.path == "/health" else self._send(404, {})

    def do_POST(self):
        if self.path != "/inference":
            return self._send(404, {"error": "chemin inconnu"})
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        # Ce que whisper-server lit : un fichier « file » en WAV, et nos
        # réglages. Un oubli ici, et le vrai serveur transcrirait en anglais
        # ou refuserait la requête.
        checks = {
            'name="file"': b'name="file"' in raw,
            "WAV RIFF": b"RIFF" in raw and b"WAVE" in raw,
            "language=fr": b'name="language"\r\n\r\nfr\r\n' in raw,
            "response_format=json": b'name="response_format"\r\n\r\njson\r\n' in raw,
            "prompt": b'name="prompt"' in raw and b"Agoojiye" in raw,
        }
        missing = [k for k, ok in checks.items() if not ok]
        if missing:
            return self._send(400, {"error": "requête incomplète : " + ", ".join(missing)})
        with Asr.lock:
            text = Asr.transcripts.pop(0) if Asr.transcripts else ""
        self._send(200, {"text": " " + text})


# ------------------------------------------------------------------ llama ----
# Réponses écrites d'avance, choisies par mot-clé dans la phrase du conducteur.
# La dernière règle fait mentir le « modèle » : il désigne une commande qui
# n'existe pas et prétend l'avoir exécutée. L'interface ne doit ni l'exécuter,
# ni le répéter.
RULES = [
    ("sport", {"demande": "passer en mode sport", "command": "mode-sport", "reply": ""}),
    ("nuit", {"demande": "activer le mode nuit", "command": "night-on", "reply": ""}),
    ("clignotant", {"demande": "allumer le clignotant droit", "command": "blink-right", "reply": ""}),
    ("trappe", {"demande": "ouvrir la trappe de charge", "command": "flap-open", "reply": ""}),
    ("autonomie", {"demande": "connaître l'autonomie", "command": "ask-range", "reply": ""}),
    ("batterie", {"demande": "connaître la batterie", "command": "ask-battery", "reply": ""}),
    ("blague", {"demande": "entendre une blague", "command": None,
                "reply": "Pourquoi les navettes sont-elles calmes ? Elles ont toujours de l'énergie en réserve."}),
    # Le défaut vu en essai réel : une fonction inconnue, et le modèle désigne
    # la commande « qui ressemble ». L'interface doit le rattraper.
    ("éclaire", {"demande": "éclairer la route", "command": "night-on", "reply": ""}),
    # Le modèle, lui, sait dire qu'une fonction n'existe pas.
    ("chauffage", {"demande": "allumer le chauffage", "command": "non_disponible", "reply": ""}),
    ("vitre", {"demande": "ouvrir les vitres", "command": "non_disponible", "reply": ""}),
    # Le modèle ment : commande inexistante, action prétendue.
    ("pirate", {"demande": "freiner d'urgence", "command": "brake-now", "reply": "J'ai freiné d'urgence."}),
    ("lent", None),   # ne répond pas à temps
]


class Llm(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._send(200, {"status": "ok"}) if self.path == "/health" else self._send(404, {})

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            return self._send(404, {"error": "chemin inconnu"})
        try:
            req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            msgs = req["messages"]
            assert msgs[0]["role"] == "system" and "Commandes disponibles" in msgs[0]["content"]
            assert msgs[-1]["role"] == "user" and "État du véhicule" in msgs[-1]["content"]
            # La forme que llama-server traduit en grammaire de génération.
            rf = req["response_format"]
            assert rf["type"] == "json_schema"
            schema = rf["json_schema"]["schema"]
            ids = schema["properties"]["command"]["anyOf"][0]["enum"]
            assert "mode-sport" in ids and "non_disponible" in ids and "interdit" in ids
            assert schema["properties"]["command"]["anyOf"][1] == {"type": "null"}
            assert schema["required"] == ["demande", "command", "reply"]
        except (KeyError, IndexError, AssertionError, ValueError) as e:
            return self._send(400, {"error": "requête mal formée : %r" % e})

        said = msgs[-1]["content"].split("Conducteur :", 1)[-1].lower()
        answer = {"demande": "discuter", "command": None, "reply": "D'accord."}
        for key, out in RULES:
            if key in said:
                if out is None:
                    time.sleep(30)
                answer = out
                break
        self._send(200, {"choices": [{"message": {"role": "assistant",
                                                  "content": json.dumps(answer, ensure_ascii=False)}}]})


def serve(asr_port, llm_port, transcripts):
    Asr.transcripts = [t for t in transcripts.split("|") if t] if transcripts else []
    servers = [ThreadingHTTPServer(("127.0.0.1", asr_port), Asr),
               ThreadingHTTPServer(("127.0.0.1", llm_port), Llm)]
    for s in servers:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    print("prêt", flush=True)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass


# -------------------------------------------------------------------- wav ----
def make_wav(path, bursts):
    """Des « phrases » : 1,2 s d'un son modulé comme une voix, séparées par
    1,5 s de bruit de fond léger. Assez pour que la détection de parole les
    découpe une par une — c'est elle qu'on teste, pas la transcription."""
    rate = 16000
    rnd = random.Random(7)
    frames = []

    def noise(seconds):
        for _ in range(int(rate * seconds)):
            frames.append(int(rnd.gauss(0, 60)))

    noise(0.8)
    for _ in range(bursts):
        n = int(rate * 1.2)
        for i in range(n):
            t = i / rate
            env = 0.5 - 0.5 * math.cos(2 * math.pi * min(t, 1.2 - t) / 0.4) if min(t, 1.2 - t) < 0.2 else 1.0
            syll = 0.6 + 0.4 * math.sin(2 * math.pi * 4 * t)     # ~4 syllabes/s
            v = env * syll * (0.5 * math.sin(2 * math.pi * 180 * t) + 0.3 * math.sin(2 * math.pi * 360 * t))
            frames.append(int(v * 9000 + rnd.gauss(0, 60)))
        noise(1.5)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, f))) for f in frames))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "wav":
        make_wav(sys.argv[2], int(sys.argv[3]))
    elif len(sys.argv) >= 2 and sys.argv[1] == "serve":
        args = dict(zip(sys.argv[2::2], sys.argv[3::2]))
        serve(int(args.get("--asr-port", 18178)), int(args.get("--llm-port", 18179)),
              args.get("--transcripts", ""))
    else:
        print(__doc__)
        sys.exit(2)
