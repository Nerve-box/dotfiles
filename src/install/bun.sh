if ! command -v bun &> /dev/null; then
    # Pending [this issue](https://github.com/oven-sh/bun/issues/43642) we must install `unzip`
    apt-get update -qq
    apt-get install unzip -y -qq
    wget -qO- https://bun.com/install | bash
fi
