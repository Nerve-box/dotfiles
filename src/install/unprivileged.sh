user="nb_${HOSTNAME%%.*}"

export NB_USER=$user

if ! id -u "$user" &>/dev/null; then
    useradd --system --create-home --home-dir "/home/$user" --shell /usr/sbin/nologin "$user"
fi
