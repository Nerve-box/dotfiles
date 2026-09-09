if ! command -v git &> /dev/null; then
    apt update -qq
    apt upgrade -y -qq
    apt install git build-essential -y -qq
fi
