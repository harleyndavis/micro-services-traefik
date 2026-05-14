from django.conf import settings


def assets_url(request):
    return {
        'ASSETS_URL': settings.ASSETS_URL,
        'HOME_URL': settings.HOME_URL,
    }
