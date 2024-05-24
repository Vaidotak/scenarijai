#!/bin/bash

# Įkelkite konfigūracijos failą
source config.sh

# Patikrinkite, ar nurodytas katalogas
if [ -z "$1" ]; then
    echo "Naudojimas: $0 <katalogas>"
    exit 1
fi

directory="$1"

# Patikrinkite, ar katalogas egzistuoja
if [ ! -d "$directory" ]; then
    echo "Katalogas '$directory' neegzistuoja arba nėra katalogas"
    exit 1
fi

# Sukurkite laiko žymą
stamp=$(date +%d%m%Y_%H%M%S)

# Gaukite pirmą GPG raktą
gpg_key_id=$(gpg --list-keys --with-colons | awk -F: '/^uid/{print $10}' | head -n1)

# Patikrinkite, ar yra GPG raktas
if [ -z "$gpg_key_id" ]; then
    echo "GPG raktas nerastas"
    exit 1
fi

# Sukurkite failo vardą
filename="$(basename "$directory")-$stamp.tar.gz"

# Sukurkite archyvą
tar -czvf "$filename" -C "$(dirname "$directory")" "$(basename "$directory")"
if [ $? -ne 0 ]; then
    echo "Klaida archyvuojant failus"
    logger -p user.err "Klaida archyvuojant failus: $directory"
    exit 1
fi

# Užšifruokite archyvą su GPG
gpg --output "$filename.gpg" --encrypt --recipient "$gpg_key_id" "$filename"
if [ $? -ne 0 ]; then
    echo "Klaida užšifruojant failą"
    logger -p user.err "Klaida užšifruojant failą: $filename"
    rm "$filename"
    exit 1
fi

# Ištrinkite neužšifruotą archyvą
rm "$filename"
if [ $? -ne 0 ]; then
    echo "Klaida ištrinant neužšifruotą failą"
    logger -p user.err "Klaida ištrinant neužšifruotą failą: $filename"
    exit 1
fi

# Siųskite užšifruotą archyvą per Telegram
curl -F chat_id="${chat_id}" -F document=@"$filename.gpg" https://api.telegram.org/bot${bot_token}/sendDocument
if [ $? -ne 0 ]; then
    echo "Klaida siunčiant failą"
    logger -p user.err "Klaida siunčiant failą per Telegram: $filename.gpg"
    rm "$filename.gpg"
    exit 1
fi

# Ištrinkite užšifruotą archyvą
rm "$filename.gpg"
if [ $? -ne 0 ]; then
    echo "Klaida ištrinant užšifruotą failą"
    logger -p user.err "Klaida ištrinant užšifruotą failą: $filename.gpg"
    exit 1
fi

echo "Operacija sėkmingai baigta"
logger -p user.info "Operacija sėkmingai baigta: $filename.gpg išsiųstas ir ištrintas"
