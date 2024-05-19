#!/bin/bash

weather_data=$(curl -s "https://api.meteo.lt/v1/places/klaipeda/forecasts/long-term")
pollen_data=$(curl -s "https://www.pollenwarndienst.at/index.php?eID=appinterface&action=getAdditionalForecastData&type=city&value=801&country=LT&lang_code=en&lang_id=1&pure_json=1&cordova=1&pasyfo=1")
water_data=$(curl -s "https://api.meteo.lt/v1/hydro-stations/klaipedos-juru-uosto-vms/observations/measured/latest")


clear

declare -A weather_translations=(
    [clear]="Giedra ☀️"
    [partly-cloudy]="Mažai debesuota 🌤"
    [cloudy-with-sunny-intervals]="Debesuota su pragiedruliais ⛅"
    [cloudy]="Debesuota ☁️"
    [thunder]="Perkūnija ⛈"
    [isolated-thunderstorms]="Trumpas lietus su perkūnija 🌦"
    [thunderstorms]="Lietus su perkūnija 🌩"
    [heavy-rain-with-thunderstorms]="Smarkus lietus su perkūnija 🌧"
    [light-rain]="Nedidelis lietus 🌦"
    [rain]="Lietus 🌧"
    [heavy-rain]="Smarkus lietus 🌧"
    [light-sleet]="Nedidelė šlapdriba 🌨"
    [sleet]="Šlapdriba 🌨"
    [freezing-rain]="Lijundra 🌧"
    [hail]="Kruša 🌨"
    [light-snow]="Nedidelis sniegas 🌨"
    [snow]="Sniegas 🌨"
    [heavy-snow]="Smarkus sniegas 🌨"
    [fog]="Rūkas 🌫"
    [null]="Oro sąlygos nenustatytos"
)

get_weather_translation() {
    local translation="${weather_translations[$1]}"
    if [ -n "$translation" ]; then
        echo "$translation"
    else
        echo "Neatpažinta orų sąlyga"
    fi
}

get_wind_direction() {
    local degrees=$1
    if (( degrees >= 0 && degrees <= 22 )) || (( degrees >= 338 && degrees <= 360 )); then
        echo "Šiaurės"
    elif (( degrees >= 23 && degrees <= 67 )); then
        echo "Šiaurės rytų"
    elif (( degrees >= 68 && degrees <= 112 )); then
        echo "Rytų"
    elif (( degrees >= 113 && degrees <= 157 )); then
        echo "Pietų rytų"
    elif (( degrees >= 158 && degrees <= 202 )); then
        echo "Pietų"
    elif (( degrees >= 203 && degrees <= 247 )); then
        echo "Pietų vakarų"
    elif (( degrees >= 248 && degrees <= 292 )); then
        echo "Vakarų"
    elif (( degrees >= 293 && degrees <= 337 )); then
        echo "Šiaurės vakarų"
    else
        echo "Neatpažinta vėjo kryptis"
    fi
}

get_day_of_week() {
  date -d "$1" "+%A"
}

get_precipitation_color() {
  local precipitation=$1
  local intensity=$(printf "%.0f" "$precipitation")
  if (( $(printf "%.1f" "$precipitation") > 0 )); then
    if (( "$intensity" < 5 )); then
      echo -e "\033[0;34m" # Šviesiai mėlyna
    elif (( "$intensity" < 10 )); then
      echo -e "\033[0;34;1m" # Mėlyna
    else
      echo -e "\033[0;34;3m" # Žalia mėlyna (be mirksėjimo)
    fi
  else
    echo -e "\033[0m" # Įprasta spalva
  fi
}

get_temperature_color() {
  local temperature=$1
  if (( $(printf "%.0f" "$temperature") < 10 )); then
    echo -e "\x1b[38;5;230m" # Įprasta spalva
  elif (( $(printf "%.0f" "$temperature") < 20 )); then
    echo -e "\033[38;5;229m" # Geltona
  elif (( $(printf "%.0f" "$temperature") < 25 )); then
    echo -e "\x1b[38;5;215m" # Tamsiai geltona
  else
    echo -e "\x1b[38;5;209m" # Oranžinė (be mirksėjimo)
  fi
}

get_cloud_cover_color() {
  local cloud_cover=$1
  if (( $(printf "%.0f" "$cloud_cover") < 25 )); then
    echo -e "\033[0m" # Įprasta spalva
  elif (( $(printf "%.0f" "$cloud_cover") < 50 )); then
    echo -e "\033[0;37;1m" # Šviesiai pilka
  elif (( $(printf "%.0f" "$cloud_cover") < 75 )); then
    echo -e "\033[0;37;3m" # Pilka (be mirksėjimo)
  else
    echo -e "\033[0;37;7m" # Tamsiai pilka
  fi
}

reset_color="\033[0m"

printf "%-10s %-6s %-6s %-10s %-10s %-9s %-12s %-10s\n" "Klaipėda" "Oro" "Junt." "Debesuo-" "Krituliai" "Vėjas" "Slėgis" "Reiškiniai"
printf "%-10s %-6s %-6s %-10s %-10s %-9s %-12s %-10s\n" "Data" "temp." "temp." "tumas" "" "(gūsis)" "" ""
printf "%-10s %-6s %-6s %-10s %-10s %-9s %-12s %-10s\n" "------" "------" "------" "----------" "----------" "---------" "------------" "----------"

previous_date=""

for ((i=0; i<72; i+=1)); do
  forecast_time=$(echo "$weather_data" | jq ".forecastTimestamps[$i].forecastTimeUtc" | sed 's/"//g')
  forecast_date=$(date -d "$forecast_time" "+%Y-%m-%d")
  forecast_hour=$(date -d "$forecast_time" "+%H:%M")
  air_temp=$(echo "$weather_data" | jq ".forecastTimestamps[$i].airTemperature" | xargs printf "%.1f")
  feels_like_temp=$(echo "$weather_data" | jq ".forecastTimestamps[$i].feelsLikeTemperature" | xargs printf "%.1f")
  cloud_cover=$(echo "$weather_data" | jq ".forecastTimestamps[$i].cloudCover" | xargs printf "%.1f")
  condition_code=$(echo "$weather_data" | jq ".forecastTimestamps[$i].conditionCode" | sed 's/"//g')
  wind_speed=$(echo "$weather_data" | jq ".forecastTimestamps[$i].windSpeed" | xargs printf "%.1f")
  wind_gust=$(echo "$weather_data" | jq ".forecastTimestamps[$i].windGust" | xargs printf "%.1f")
  sea_level_pressure=$(echo "$weather_data" | jq ".forecastTimestamps[$i].seaLevelPressure" | xargs printf "%.1f")
  total_precipitation=$(echo "$weather_data" | jq ".forecastTimestamps[$i].totalPrecipitation" | xargs printf "%.1f")

  if [[ "$forecast_date" != "$previous_date" ]]; then
    day_of_week=$(get_day_of_week "$forecast_date")
    echo "$forecast_date ($day_of_week)"
    previous_date="$forecast_date"
  fi

  wind_speed_formatted=$(printf "%.1f" "$wind_speed" | tr ',' '.')
  wind_gust_formatted=$(printf "%.1f" "$wind_gust" | tr ',' '.')

  precipitation_color=$(get_precipitation_color "$total_precipitation")
  temperature_color=$(get_temperature_color "$air_temp")
  cloud_cover_color=$(get_cloud_cover_color "$cloud_cover")

  printf "%-10s %b%-6s%b %b%-6s%b %b%-10s%b %b%-10s%b %-9s %-12s %b%-10s%b\n" \
    "$forecast_hour" "$temperature_color" "$(printf "%.1f" "$air_temp" | tr ',' '.') °C" "$reset_color" \
    "$temperature_color" "$(printf "%.1f" "$feels_like_temp" | tr ',' '.') °C" "$reset_color" \
    "$cloud_cover_color" "$(printf "%.1f" "$cloud_cover" | tr ',' '.') %" "$reset_color" \
    "$precipitation_color" "$(printf "%.1f" "$total_precipitation" | tr ',' '.') mm" "$reset_color" \
    "$wind_speed_formatted ($wind_gust_formatted) m/s" "$(printf "%.1f" "$sea_level_pressure" | tr ',' '.') hPa" \
    "$reset_color" "$(get_weather_translation "$condition_code")" "$reset_color"
done

echo

today_air_quality=$(echo "$pollen_data" | jq '.result[0].air_quality')
today_dayrisk=$(echo "$pollen_data" | jq '.result[0].dayrisk')
tomorrow_air_quality=$(echo "$pollen_data" | jq '.result[1].air_quality')
tomorrow_dayrisk=$(echo "$pollen_data" | jq '.result[1].dayrisk')

water_temperature=$(echo "$water_data" | jq '.observations[0].waterTemperature' | xargs printf "%.1f")

echo "Oro kokybė: $today_air_quality"
echo "Alergijos rizika: $today_dayrisk"
echo "Vandens temperatūra Baltijos jūroje: $water_temperature °C"

read -p "Spauskite Enter, kad išvalytumėte terminalo langą..." input
clear
