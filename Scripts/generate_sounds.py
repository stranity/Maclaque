#!/usr/bin/env python3
"""
generate_sounds.py — Generate French voice clips for Maclaque sound packs
using ElevenLabs Text-to-Speech API.

Usage:
    export ELEVENLABS_API_KEY="your_key_here"
    python3 generate_sounds.py

Requires: pip install requests
"""

import json
import os
import struct
import sys
import time
import requests

API_URL = "https://api.elevenlabs.io/v1/text-to-speech"
API_KEY = os.environ.get("ELEVENLABS_API_KEY")

if not API_KEY:
    print("Error: ELEVENLABS_API_KEY environment variable not set.")
    sys.exit(1)


# ── Voice settings per pack ─────────────────────────────────────────────
# Each pack has tailored voice_settings for realism:
#   - stability: lower = more expressive/emotional (good for screams)
#   - similarity_boost: higher = closer to original voice
#   - style: higher = more dramatic delivery
VOICE_PROFILES = {
    "male_young": {
        "stability": 0.35,
        "similarity_boost": 0.75,
        "style": 0.6,
        "use_speaker_boost": True,
    },
    "female_elderly": {
        "stability": 0.40,
        "similarity_boost": 0.80,
        "style": 0.5,
        "use_speaker_boost": True,
    },
    "male_tired": {
        "stability": 0.50,
        "similarity_boost": 0.70,
        "style": 0.4,
        "use_speaker_boost": True,
    },
    "male_solemn": {
        "stability": 0.55,
        "similarity_boost": 0.85,
        "style": 0.3,
        "use_speaker_boost": True,
    },
    "male_street": {
        "stability": 0.30,
        "similarity_boost": 0.70,
        "style": 0.7,
        "use_speaker_boost": True,
    },
}


# ── Sound configuration ─────────────────────────────────────────────────
SOUNDS_CONFIG = {
    "aie": {
        "voice_id": "IKne3meq5aSn9XLyUdCD",  # Charlie — premade, male, energetic
        "profile": "male_young",
        "clips": [
            # ── Gifles ──
            {"file": "aie_01.mp3", "text": "Aïe !"},
            {"file": "aie_02.mp3", "text": "Aïe, doucement !"},
            {"file": "aie_03.mp3", "text": "Oh, ça pique."},
            {"file": "ouille_01.mp3", "text": "Ouille ouille ouille !"},
            {"file": "ouille_02.mp3", "text": "Aïe ! Mais t'es malade ?!"},
            {"file": "aie_fort_01.mp3", "text": "AÏÏÏE ! Mais arrête !"},
            {"file": "aie_fort_02.mp3", "text": "Oh la vache, ça fait mal !"},
            {"file": "cri_01.mp3", "text": "AAAAAAH ! NON MAIS ÇA VA PAS ?!"},
            {"file": "cri_02.mp3", "text": "OUILLE ! T'ES FOU OU QUOI ?!"},
            {"file": "cri_03.mp3", "text": "AAAAÏE ! JE VAIS TE TUER !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Ahhh, ça fait du bien un peu d'énergie."},
            {"file": "charge_plug_02.mp3", "text": "Mmmh, enfin branchééé."},
            {"file": "charge_plug_03.mp3", "text": "Oh oui, du jus ! J'en pouvais plus."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "Hé ! Remets-moi ça tout de suite !"},
            {"file": "charge_unplug_02.mp3", "text": "Non non non, j'avais pas fini de charger !"},
            {"file": "charge_unplug_03.mp3", "text": "Aïe ! Mon énergie !"},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "Bonne nuit..."},
            {"file": "lid_close_02.mp3", "text": "Ah, enfin la paix."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Oh non, encore toi..."},
            {"file": "lid_open_02.mp3", "text": "Mmmmh... Quoi encore ?"},
        ],
    },
    "putain": {
        "voice_id": "N2lVS1w4EtoT3dr4eOWO",  # Callum — premade, male, husky
        "profile": "male_young",
        "clips": [
            # ── Gifles ──
            {"file": "putain_01.mp3", "text": "Oh putain..."},
            {"file": "putain_02.mp3", "text": "Fait chier."},
            {"file": "putain_03.mp3", "text": "Roh, c'est bon là."},
            {"file": "bordel_01.mp3", "text": "Putain mais c'est quoi ce bordel ?!"},
            {"file": "bordel_02.mp3", "text": "Oh le bâtard, il m'a frappé !"},
            {"file": "merde_01.mp3", "text": "Merde ! Mais t'es sérieux là ?!"},
            {"file": "merde_02.mp3", "text": "Putain de merde, ça fait mal !"},
            {"file": "putain_forte_01.mp3", "text": "PUTAIN ! MAIS T'ES FOU ?!"},
            {"file": "putain_forte_02.mp3", "text": "BORDEL DE MERDE ! ARRÊTE !"},
            {"file": "putain_forte_03.mp3", "text": "PUTAIN ! JE VAIS PÉTER UN CÂBLE !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Putain enfin ! J'étais à deux doigts de crever."},
            {"file": "charge_plug_02.mp3", "text": "Oh putain oui, branche-moi, branche-moi !"},
            {"file": "charge_plug_03.mp3", "text": "Bordel, il était temps."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "PUTAIN ! Remets le câble connard !"},
            {"file": "charge_unplug_02.mp3", "text": "Oh le fils de pute, il m'a débranché !"},
            {"file": "charge_unplug_03.mp3", "text": "Fait chier, j'étais même pas à cent pour cent !"},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "Oh putain, il m'étouffe là !"},
            {"file": "lid_close_02.mp3", "text": "Ferme ta gueule toi-même, connard."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Putain, enfin de l'air !"},
            {"file": "lid_open_02.mp3", "text": "Oh bordel, t'es encore là toi ?"},
        ],
    },
    "mamie": {
        "voice_id": "pFZP5JQG7iQjIQuC4Bku",  # Lily — premade, female, velvety
        "profile": "female_elderly",
        "clips": [
            # ── Gifles ──
            {"file": "mamie_doucement_01.mp3", "text": "Oh mon petit, doucement."},
            {"file": "mamie_doucement_02.mp3", "text": "Dis donc, on se calme."},
            {"file": "mamie_doucement_03.mp3", "text": "Tss tss, c'est pas des manières."},
            {"file": "mamie_reproche_01.mp3", "text": "Non mais oh ! C'est comme ça qu'on traite les choses ?!"},
            {"file": "mamie_reproche_02.mp3", "text": "Tu vas me faire le plaisir d'arrêter ça tout de suite !"},
            {"file": "mamie_reproche_03.mp3", "text": "Attends un peu que je le dise à ta mère !"},
            {"file": "mamie_cri_01.mp3", "text": "MAIS T'ES DEVENU FOU ?! MON DIEU !"},
            {"file": "mamie_cri_02.mp3", "text": "AU SECOURS ! IL EST DEVENU VIOLENT !"},
            {"file": "mamie_cri_03.mp3", "text": "MAIS QU'EST-CE QUE J'AI FAIT AU BON DIEU ?!"},
            {"file": "mamie_cri_04.mp3", "text": "SACRÉ NOM D'UNE PIPE ! ARRÊTE ÇA !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Ah, tu penses enfin à me nourrir."},
            {"file": "charge_plug_02.mp3", "text": "C'est bien mon petit, mets-moi à charger."},
            {"file": "charge_plug_03.mp3", "text": "Mmmmh, ça fait du bien, merci mon chou."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "Mais enfin ! J'avais pas fini !"},
            {"file": "charge_unplug_02.mp3", "text": "On débranche pas mamie comme ça, petit voyou !"},
            {"file": "charge_unplug_03.mp3", "text": "Tsss, aucun respect pour les anciens."},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "Ah, c'est l'heure de la sieste. Bonne nuit mon petit."},
            {"file": "lid_close_02.mp3", "text": "On ferme la boutique ! À demain."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Oh, bonjour mon petit ! T'as bien dormi ?"},
            {"file": "lid_open_02.mp3", "text": "Ah te revoilà ! Mamie s'ennuyait toute seule."},
        ],
    },
    "smic": {
        "voice_id": "pNInz6obpgDQGcFmaJgB",  # Adam — premade, male, firm
        "profile": "male_tired",
        "clips": [
            # ── Gifles ──
            {"file": "smic_soupir_01.mp3", "text": "Encore une journée au SMIC..."},
            {"file": "smic_soupir_02.mp3", "text": "C'est pas avec mon salaire que je vais réparer ça."},
            {"file": "smic_soupir_03.mp3", "text": "J'ai pas les moyens d'être maltraité comme ça."},
            {"file": "smic_pleurs_01.mp3", "text": "En plus je suis au SMIC ! Vous voulez quoi de plus ?!"},
            {"file": "smic_pleurs_02.mp3", "text": "Mon loyer augmente ET tu me frappes ?!"},
            {"file": "smic_ral_01.mp3", "text": "L'inflation plus les coups, super ma vie !"},
            {"file": "smic_ral_02.mp3", "text": "J'ai même pas les moyens d'aller aux urgences !"},
            {"file": "smic_cri_01.mp3", "text": "JE SUIS AU SMIC ! J'AI PAS BESOIN DE ÇA EN PLUS !"},
            {"file": "smic_cri_02.mp3", "text": "J'AI MÊME PAS LA MUTUELLE POUR ÇA !"},
            {"file": "smic_cri_03.mp3", "text": "TU SAIS COMBIEN ÇA COÛTE UN MAC ?! J'AI PRIS UN CRÉDIT !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Ah, l'électricité gratuite... profite, c'est la seule chose qui l'est."},
            {"file": "charge_plug_02.mp3", "text": "Au moins ça c'est pas payant. Enfin, la facture EDF..."},
            {"file": "charge_plug_03.mp3", "text": "Branche-moi, j'ai même plus la force de râler."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "Et voilà, même l'électricité on me la coupe."},
            {"file": "charge_unplug_02.mp3", "text": "J'aurais dû prendre le forfait illimité..."},
            {"file": "charge_unplug_03.mp3", "text": "Débranché. Comme mon compte en banque de la réalité."},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "Au moins quand je dors ça me coûte rien."},
            {"file": "lid_close_02.mp3", "text": "Bonne nuit. Demain c'est encore le SMIC."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Oh non... encore une journée de travail."},
            {"file": "lid_open_02.mp3", "text": "J'ai rêvé qu'on m'augmentait. C'était bien."},
        ],
    },
    "president": {
        "voice_id": "JBFqnCBsd6RMkjVDRZzb",  # George — premade, male, warm storyteller
        "profile": "male_solemn",
        "clips": [
            # ── Gifles ──
            {"file": "pres_calme_01.mp3", "text": "Mes chers compatriotes, un peu de retenue."},
            {"file": "pres_calme_02.mp3", "text": "Je vous demande de vous arrêter."},
            {"file": "pres_calme_03.mp3", "text": "Ce geste ne correspond pas aux valeurs de la République."},
            {"file": "pres_agace_01.mp3", "text": "Écoutez, je traverse la rue et je vous gifle !"},
            {"file": "pres_agace_02.mp3", "text": "Casse-toi, pauv' con !"},
            {"file": "pres_agace_03.mp3", "text": "Vous n'avez pas le monopole de la violence !"},
            {"file": "pres_colere_01.mp3", "text": "C'EST UNE ATTEINTE À LA DIGNITÉ DE LA FONCTION !"},
            {"file": "pres_colere_02.mp3", "text": "JE DISSOUS L'ASSEMBLÉE ! VOILÀ !"},
            {"file": "pres_colere_03.mp3", "text": "ARTICLE 49-3 ! ON DISCUTE PLUS !"},
            {"file": "pres_colere_04.mp3", "text": "LA FRANCE NE SE LAISSE PAS GIFLER !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Le nucléaire français alimente la nation."},
            {"file": "charge_plug_02.mp3", "text": "L'énergie de la France coule dans mes veines."},
            {"file": "charge_plug_03.mp3", "text": "Branché au réseau. Comme l'Élysée à la fibre."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "Qui a coupé le courant ?! C'est un coup d'état !"},
            {"file": "charge_unplug_02.mp3", "text": "On ne débranche pas la République !"},
            {"file": "charge_unplug_03.mp3", "text": "Coupure de courant ? J'appelle EDF immédiatement."},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "La séance est levée. Bonsoir la France."},
            {"file": "lid_close_02.mp3", "text": "Françaises, Français, bonne nuit."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Mes chers compatriotes, bonjour."},
            {"file": "lid_open_02.mp3", "text": "La France se réveille. Et elle est en colère."},
        ],
    },
    "populaire": {
        "voice_id": "TX3LPaxmHKxFdv7VOQHJ",  # Liam — premade, male, energetic social media
        "profile": "male_street",
        "clips": [
            # ── Gifles ──
            {"file": "pop_light_01.mp3", "text": "Hé oh, tranquille frère."},
            {"file": "pop_light_02.mp3", "text": "Wesh, calme-toi là."},
            {"file": "pop_light_03.mp3", "text": "Eh, c'est quoi ton problème gros ?"},
            {"file": "pop_medium_01.mp3", "text": "Wallah tu vas me taper comme ça ?! T'as cru c'était quoi ici ?!"},
            {"file": "pop_medium_02.mp3", "text": "Frère ! Tu me gifles devant tout le monde là ?! T'as pas la honte ?!"},
            {"file": "pop_medium_03.mp3", "text": "Sur la vie de ma mère, tu refais ça je t'emmerde !"},
            {"file": "pop_medium_04.mp3", "text": "Nique sa mère ! Mais arrête de me frapper là !"},
            {"file": "pop_hard_01.mp3", "text": "WALLAH JE VAIS T'EMBOUCANER ! TU ME CONNAIS PAS !"},
            {"file": "pop_hard_02.mp3", "text": "WESH ! TU CROIS C'EST QUI QUI TAPE LÀ ?! J'SUIS PAS TON POTE !"},
            {"file": "pop_hard_03.mp3", "text": "SUR LA VIE DE MA MÈRE J'VAIS TE RETOURNER ! ARRÊTE ÇA TOUT DE SUITE !"},
            {"file": "pop_hard_04.mp3", "text": "FRÈRE ! T'ES UN OUF TOI ! VIENS ON SORT DEHORS !"},
            # ── Branchement ──
            {"file": "charge_plug_01.mp3", "text": "Wesh, enfin du jus ! J'étais dead là."},
            {"file": "charge_plug_02.mp3", "text": "Ah frère, branche-moi, wallah j'suis à zéro."},
            {"file": "charge_plug_03.mp3", "text": "Le câble ! Hamdoulilah, j'suis sauvé."},
            # ── Débranchement ──
            {"file": "charge_unplug_01.mp3", "text": "Wesh ! Remets le câble ou j'te jure c'est la guerre !"},
            {"file": "charge_unplug_02.mp3", "text": "Frère, t'as cru c'était gratuit la batterie ?! Rebranche !"},
            {"file": "charge_unplug_03.mp3", "text": "Wallah tu me laisses crever comme ça ?!"},
            # ── Fermeture couvercle ──
            {"file": "lid_close_01.mp3", "text": "Bonne nuit le sang, à demain."},
            {"file": "lid_close_02.mp3", "text": "Wesh, on se ferme. Bonne night frère."},
            # ── Ouverture couvercle ──
            {"file": "lid_open_01.mp3", "text": "Wesh wesh, quoi de neuf le reuf ?"},
            {"file": "lid_open_02.mp3", "text": "Ah frère, tu m'as réveillé là ! Ça va ou quoi ?"},
        ],
    },
}


def find_french_voice(voices, hint="french male"):
    """Find the best matching French voice from available voices."""
    hint_lower = hint.lower()
    want_female = "female" in hint_lower or "femme" in hint_lower

    candidates = []
    for v in voices:
        labels = v.get("labels", {})
        name = v.get("name", "").lower()
        lang = labels.get("language", "").lower()
        accent = labels.get("accent", "").lower()
        gender = labels.get("gender", "").lower()
        desc = labels.get("description", "").lower()
        use_case = labels.get("use_case", "").lower()

        # Check if French
        is_french = (
            "french" in lang
            or "français" in lang
            or "french" in accent
            or "french" in name
            or "fr" == lang
        )

        if not is_french:
            continue

        # Gender match
        if want_female and gender == "female":
            candidates.insert(0, v)  # Prioritize
        elif not want_female and gender == "male":
            candidates.insert(0, v)
        else:
            candidates.append(v)

    return candidates[0] if candidates else None


def generate_clip(voice_id, text, output_path, voice_settings):
    """Generate a single audio clip via ElevenLabs TTS."""
    # Use mp3 output format (passed as query parameter)
    resp = requests.post(
        f"{API_URL}/{voice_id}?output_format=mp3_44100_128",
        headers={
            "xi-api-key": API_KEY,
            "Content-Type": "application/json",
        },
        json={
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": voice_settings,
        },
    )

    if resp.status_code == 200:
        # Change extension to .mp3
        mp3_path = output_path.rsplit(".", 1)[0] + ".mp3"
        with open(mp3_path, "wb") as f:
            f.write(resp.content)

        print(f"  ✓ {os.path.basename(mp3_path):30s} ({len(resp.content)} bytes) — \"{text}\"")
        return True
    else:
        print(f"  ✗ {os.path.basename(output_path):30s} — HTTP {resp.status_code}: {resp.text[:100]}")
        return False


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    packs_dir = os.path.join(script_dir, "..", "Resources", "Packs")

    print("🎤 Maclaque Sound Generator — ElevenLabs")
    print("=" * 50)

    # ── Fetch all available voices ──────────────────────────────────
    print("Fetching voices...")
    resp = requests.get(
        "https://api.elevenlabs.io/v1/voices",
        headers={"xi-api-key": API_KEY},
    )
    resp.raise_for_status()
    all_voices = resp.json()["voices"]
    print(f"Found {len(all_voices)} voices total.\n")

    # Show available French voices
    french_voices = [
        v for v in all_voices
        if "french" in v.get("labels", {}).get("language", "").lower()
        or "french" in v.get("labels", {}).get("accent", "").lower()
        or "french" in v.get("name", "").lower()
    ]
    if french_voices:
        print(f"🇫🇷 French voices detected: {len(french_voices)}")
        for v in french_voices[:8]:
            labels = v.get("labels", {})
            print(f"   • {v['name']} ({v['voice_id'][:12]}...) "
                  f"— {labels.get('gender', '?')}, {labels.get('description', '?')}")
        print()
    else:
        print("⚠ No French-labeled voices found. Using first available voice.\n")

    # Fallback voice
    fallback = all_voices[0] if all_voices else None
    if not fallback:
        print("Error: No voices available on this account.")
        sys.exit(1)

    total = 0
    success = 0

    for pack_id, pack_config in SOUNDS_CONFIG.items():
        pack_dir = os.path.join(packs_dir, pack_id)
        os.makedirs(pack_dir, exist_ok=True)

        # Use hardcoded voice_id (premade voices work on free tier)
        voice_id = pack_config.get("voice_id")
        if not voice_id:
            hint = pack_config.get("voice_name_hint", "french male")
            voice = find_french_voice(all_voices, hint) or fallback
            voice_id = voice["voice_id"]

        profile_name = pack_config.get("profile", "male_young")
        voice_settings = VOICE_PROFILES.get(profile_name, VOICE_PROFILES["male_young"])

        print(f"📦 Pack: {pack_id}")
        print(f"   Voice ID: {voice_id[:16]}...")
        print(f"   Profile: {profile_name}")
        print()

        for clip in pack_config["clips"]:
            total += 1
            output_path = os.path.join(pack_dir, clip["file"])

            if os.path.exists(output_path):
                print(f"  ⏭ {clip['file']:30s} — (exists, skipping)")
                success += 1
                continue

            if generate_clip(voice_id, clip["text"], output_path, voice_settings):
                success += 1

            # Rate limiting
            time.sleep(0.5)

        print()

    print("=" * 50)
    print(f"Done: {success}/{total} clips generated.")
    if success < total:
        print(f"⚠ {total - success} clips failed. Re-run to retry (existing files are skipped).")


if __name__ == "__main__":
    main()
