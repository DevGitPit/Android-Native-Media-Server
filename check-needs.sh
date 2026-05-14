#!/data/data/com.termux/files/usr/bin/bash

# Configuration
SONARR_DB="$HOME/.config/Sonarr/sonarr.db"
RADARR_DB="$HOME/.config/Radarr/radarr.db"
SQLITE_OPTS="-init /dev/null -list -noheader"

check_sonarr() {
    # Check for missing monitored episodes that aired more than 1 hour ago
    # (We wait 1 hour after release to ensure it is indexed and available)
    MISSING=$(sqlite3 $SQLITE_OPTS "$SONARR_DB" "SELECT COUNT(*) FROM Episodes WHERE Monitored = 1 AND EpisodeFileId = 0 AND AirDateUtc < datetime('now', '-1 hour');" 2>/dev/null)
    
    if [[ "$MISSING" -gt 0 ]]; then
        echo "SONARR_MISSING:$MISSING"
    else
        echo "SONARR_IDLE"
    fi
}

check_radarr() {
    # Check for missing monitored movies released more than 1 hour ago
    MISSING=$(sqlite3 $SQLITE_OPTS "$RADARR_DB" "SELECT COUNT(*) FROM Movies m JOIN MovieMetadata mm ON m.MovieMetadataId = mm.Id WHERE m.Monitored = 1 AND m.MovieFileId = 0 AND ((mm.DigitalRelease IS NOT NULL AND mm.DigitalRelease < datetime('now', '-1 hour')) OR (mm.PhysicalRelease IS NOT NULL AND mm.PhysicalRelease < datetime('now', '-1 hour')));" 2>/dev/null)
    
    if [[ "$MISSING" -gt 0 ]]; then
        echo "RADARR_MISSING:$MISSING"
    else
        echo "RADARR_IDLE"
    fi
}

check_transmission() {
    # If Transmission isn't running, it's idle
    if ! pgrep -x "transmission-daemon" > /dev/null; then
        echo "TRANSMISSION_IDLE"
        return
    fi

    # Check for active (downloading/seeding) or incomplete torrents
    TORRENT_COUNT=$(transmission-remote -l 2>/dev/null | grep -vE "Sum:|ID" | wc -l)
    
    if [[ "$TORRENT_COUNT" -gt 0 ]]; then
        # Check if any are actually downloading or not finished
        ACTIVE=$(transmission-remote -l 2>/dev/null | grep -v "Finished" | grep -vE "Sum:|ID" | wc -l)
        if [[ "$ACTIVE" -gt 0 ]]; then
            echo "TRANSMISSION_ACTIVE:$ACTIVE"
        else
            echo "TRANSMISSION_IDLE"
        fi
    else
        echo "TRANSMISSION_IDLE"
    fi
}

get_next_release() {
    # Get next Sonarr release (aired more than 1 hour ago doesn't count, we want the future)
    NEXT_SONARR=$(sqlite3 $SQLITE_OPTS "$SONARR_DB" "SELECT AirDateUtc FROM Episodes WHERE Monitored = 1 AND EpisodeFileId = 0 AND AirDateUtc > datetime('now') ORDER BY AirDateUtc ASC LIMIT 1;" 2>/dev/null)
    
    # Get next Radarr release
    NEXT_RADARR=$(sqlite3 $SQLITE_OPTS "$RADARR_DB" "SELECT MIN(release) FROM (SELECT DigitalRelease as release FROM Movies m JOIN MovieMetadata mm ON m.MovieMetadataId = mm.Id WHERE m.Monitored = 1 AND m.MovieFileId = 0 AND DigitalRelease > datetime('now') UNION SELECT PhysicalRelease as release FROM Movies m JOIN MovieMetadata mm ON m.MovieMetadataId = mm.Id WHERE m.Monitored = 1 AND m.MovieFileId = 0 AND PhysicalRelease > datetime('now')) WHERE release IS NOT NULL;" 2>/dev/null)

    # Return the earliest one
    if [[ -z "$NEXT_SONARR" ]]; then
        echo "$NEXT_RADARR"
    elif [[ -z "$NEXT_RADARR" ]]; then
        echo "$NEXT_SONARR"
    else
        # Compare strings (ISO dates sort lexicographically)
        if [[ "$NEXT_SONARR" < "$NEXT_RADARR" ]]; then
            echo "$NEXT_SONARR"
        else
            echo "$NEXT_RADARR"
        fi
    fi
}

case "$1" in
    all)
        check_sonarr
        check_radarr
        check_transmission
        ;;
    next)
        get_next_release
        ;;
    sonarr)
        check_sonarr
        ;;
    radarr)
        check_radarr
        ;;
    transmission)
        check_transmission
        ;;
    *)
        echo "Usage: $0 {all|sonarr|radarr|transmission}"
        exit 1
        ;;
esac
