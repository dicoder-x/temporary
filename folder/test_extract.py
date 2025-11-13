import pytest
from unittest.mock import patch
from extract import fetch_plant


@pytest.fixture
def sample_plant_data():
    """Sample plant data fixture for testing"""
    return {
        'plant_id': 2,
        'data': {'json': 1},
        'error': None
    }


@patch("extract.requests.get", return_value=None)
def test_fetch_plant_missing_data(missing_data):
    """Tests how the fetch_plant function handles missing data"""
    response = fetch_plant(1)
    assert '404 Client Error' in response.get('error')
    assert not response.get('data')
    assert response.get('plant_id') == 1


@patch("extract.requests.get", return_value=sample_plant_data)
def test_fetch_plant_wrong_id():
    """Tests how the fetch_plant function handles a wrong id"""
    assert fetch_plant(3).get('plant_id') == 2
