"""Configura apenas URL e chave pública; usa somente a biblioteca padrão."""
import base64
import json
from pathlib import Path
from urllib.parse import urlparse


def main():
    url = input("Cole a Project URL do Supabase: ").strip()
    key = input("Cole a chave pública Publishable/anon: ").strip()
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username:
        raise ValueError("Use uma Project URL HTTPS válida.")
    if not key or key.startswith("sb_secret_"):
        raise ValueError("Use a chave pública, nunca uma chave administrativa.")
    parts = key.split(".")
    if len(parts) == 3:
        try:
            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
        except (ValueError, UnicodeError):
            payload = {}
        if isinstance(payload, dict) and payload.get("role") == "service_role":
            raise ValueError("service_role é administrativa; use a chave pública anon.")
    config = Path(__file__).resolve().parents[1] / "config" / "supabase.json"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps({
        "SUPABASE_URL": url,
        "SUPABASE_PUBLISHABLE_KEY": key,
    }, indent=2) + "\n", encoding="utf-8")
    print("Configuração salva em config/supabase.json")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, EOFError) as error:
        raise SystemExit(f"Configuração não salva: {error}")
