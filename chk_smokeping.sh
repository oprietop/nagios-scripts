#!/bin/sh
set -u

secrets="/etc/smokeping/smokeping_secrets"
problems=""

# Probamos que el fichero secrets existe es legible.
test -r $secrets -a -f $secrets || { echo "No puedo leer $secrets" ; exit 1 ; }

# Iteramos cada línea por los hosts que contiene (formato host:password)
for host in $(cat /etc/smokeping/smokeping_secrets | cut -d: -f1 | xargs)
do
    # Nos conectamos por ssh y recogemos el número de procesos. El proceso lo tiramos a background.
    res=$(ssh root@$host 'pgrep -fc [s]mokeping'&)
    # Mostramos los procesos que vamos encontrados por STDERR.
    echo "$host has $res Smokeping processes" 1>&2;
    # Si hemos tenido problemas añadimos el host al string problemas.
    test $res -eq 0 && problems="$problems $host"
done

# Esperamos a que todos los procesos que hemos forqueado se resuelvan.
wait

# Salimos con 0 si todo fué OK o con 1 y el string de host problemáticos.
test -z "$problems" && { echo "OK"; exit 0; } || { echo "Los hosts$problems tienen problemas"; exit 1; }
