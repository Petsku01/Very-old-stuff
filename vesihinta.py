import requests
import time
from datetime import datetime
import logging

# Lokituksen asetukset
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Asetukset
HINTA_KYNNYS = 0.05  # Hinta kynnys EUR/kWh (säädä tarpeen mukaan)
TARKISTUSVALI = 300  # Tarkista 5 minuutin välein (sekunteina)
VEDENLAHMITTIMEN_TEHO = 2.0  # Vedenlämmittimen teho kW
MAKSIMI_LAMMITYSAIKA = 3600  # Maksimi lämmitysaika sekunteina (1 tunti)

# Esimerkkirajapinta (korvaa oikealla sähkön hinta-API:lla)
HINTA_API_URL = "https://api.example.com/electricity/price"

# API-avain (korvaa oikealla avaimella)
API_AVAIN = "sinun_api_avaimesi"

def hae_nykyinen_sahkohinta():
    """Hae nykyinen sähkön hinta API:sta."""
    try:
        headers = {"Authorization": f"Bearer {API_AVAIN}"}
        vastaus = requests.get(HINTA_API_URL, headers=headers)
        vastaus.raise_for_status()
        data = vastaus.json()
        # Oletetaan, että API palauttaa hinnan EUR/kWh avaimella 'price'
        nykyinen_hinta = data.get("price")
        if nykyinen_hinta is None:
            raise ValueError("Hintadataa ei löydy API-vastauksesta")
        return nykyinen_hinta
    except requests.RequestException as e:
        logging.error(f"Hinnan haku epäonnistui: {e}")
        return None
    except ValueError as e:
        logging.error(f"Virheellinen hintadata: {e}")
        return None

def ohjaa_vedenlammittimen(hinta):
    """Ohjaa vedenlämmitintä sähkön hinnan perusteella."""
    if hinta is None:
        logging.warning("Ei kelvollista hintadataa, vedenlämmitin pysyy pois päältä")
        return False

    if hinta < HINTA_KYNNYS:
        logging.info(f"Hinta {hinta:.3f} EUR/kWh on alle kynnyksen {HINTA_KYNNYS:.3f}. Käynnistetään vedenlämmitin.")
        # Simuloi vedenlämmittimen käynnistys (korvaa oikealla laiteohjauksella)
        return True
    else:
        logging.info(f"Hinta {hinta:.3f} EUR/kWh on yli kynnyksen {HINTA_KYNNYS:.3f}. Vedenlämmitin pysyy pois päältä.")
        return False

def simuloi_lammittimen_toiminta():
    """Simuloi vedenlämmittimen toimintaa turvallisuustarkistuksilla."""
    aloitusaika = time.time()
    while time.time() - aloitusaika < MAKSIMI_LAMMITYSAIKA:
        # Tarkista hinta säännöllisesti toiminnan aikana
        nykyinen_hinta = hae_nykyinen_sahkohinta()
        if nykyinen_hinta is None or nykyinen_hinta >= HINTA_KYNNYS:
            logging.info("Hinta nousi tai ei kelvollinen, pysäytetään lämmitin.")
            return
        time.sleep(60)  # Tarkista joka minuutti toiminnan aikana
    logging.info("Maksimi lämmitysaika saavutettu, pysäytetään lämmitin.")

def paaohjelma():
    """Pääsilmukka hintojen tarkkailuun ja vedenlämmittimen ohjaukseen."""
    while True:
        try:
            # Hae nykyinen sähkön hinta
            nykyinen_hinta = hae_nykyinen_sahkohinta()
            
            # Ohjaa vedenlämmitintä hinnan perusteella
            if ohjaa_vedenlammittimen(nykyinen_hinta):
                # Simuloi lämmittimen toimintaa (korvaa oikealla laiteohjauksella)
                simuloi_lammittimen_toiminta()
            
            # Odota ennen seuraavaa tarkistusta
            time.sleep(TARKISTUSVALI)
            
        except KeyboardInterrupt:
            logging.info("Ohjelma keskeytetty käyttäjän toimesta.")
            break
        except Exception as e:
            logging.error(f"Odottamaton virhe: {e}")
            time.sleep(TARKISTUSVALI)  # Estä nopeat virhesilmukat

if __name__ == "__main__":
    paaohjelma()
