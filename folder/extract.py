"""Extract script to fetch all plants"""

import requests

BASE_URL = "https://sigma-labs-bot.herokuapp.com/api/plants"
TOTAL_PLANTS = 50
TIMEOUT = 10


def fetch_plant(plant_id: int) -> dict:
    """Fetch plant data given plant id"""
    try:
        response = requests.get(f"{BASE_URL}/{plant_id}", timeout=TIMEOUT)
        response.raise_for_status()
        return {"plant_id": plant_id, "data": response.json(), "error": None}
    except Exception as e:
        return {"plant_id": plant_id, "data": None, "error": str(e)}


def fetch_all_plants() -> list[dict]:
    """Fetch all plants"""
    data = []
    for plant_id in range(1, TOTAL_PLANTS + 1):
        plant = fetch_plant(plant_id)
        data.append(plant)
    return data


def main():
    """Main function"""
    plants = fetch_all_plants()
    print(f"Fetched {len(plants)} plants")
    return plants


if __name__ == "__main__":
    print(main())
