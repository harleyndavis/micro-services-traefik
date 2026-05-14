from django.contrib import admin
from .models import Link


@admin.register(Link)
class LinkAdmin(admin.ModelAdmin):
    list_display = ['short_code', 'original_url', 'clicks', 'qr_scans', 'created_at']
    search_fields = ['short_code', 'original_url']
    readonly_fields = ['short_code', 'clicks', 'qr_scans', 'created_at', 'updated_at']
    ordering = ['-created_at']
