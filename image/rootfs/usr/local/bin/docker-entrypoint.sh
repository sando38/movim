#!/bin/bash

set -e
set -u

myself=${0##*/}

info()
{
	echo "$myself: $*"
}

copy_movim ()
{
	cd /tmp/movim
	tar cf - * | ( cd $MOVIM_HOME; tar xfp -)
	info "Complete! Movim ${MOVIM_VERSION} has been successfully copied to $MOVIM_HOME"
	cd $MOVIM_HOME
	echo "$MOVIM_VERSION" > CTR_TAG
}

create_db_test_script ()
{
	local script="$1"
	
	# credits to https://stackoverflow.com/a/31631143
	cat > "$script" <<-'EOF'
	<?php
		$wait = 1; // wait Timeout In Seconds
		$host = 'DB_HOST';
		$ports = [
			'db' => DB_PORT,
		];
	
		foreach ($ports as $key => $port) {
		$fp = @fsockopen($host, $port, $errCode, $errStr, $wait);
		echo "Ping $host:$port ($key) ==> ";
		if ($fp) {
			echo 'SUCCESS';
			fclose($fp);
		} else {
			echo "ERROR: $errCode - $errStr";
		}
		echo PHP_EOL;
		}
	?>
	EOF
	
	sed -i "s|DB_HOST|${DB_HOST:-localhost}|" "$script"
	sed -i "s|DB_PORT|${DB_PORT:-5432}|" "$script"
}

info 'Start ctr run script ...'
info "Container image is based on movim $MOVIM_VERSION ..."
cd $MOVIM_HOME

if [ ! -f CTR_TAG ] && [ -f VERSION ]; then
	echo "$(cat VERSION)" > CTR_TAG
fi

# copy image's movim version into workdir
if ! [ -e daemon.php -a -e public/index.php ]; then
	info "Movim not found in $MOVIM_HOME - copying now ..."
	if [ "$(ls -A)" ]; then
		info "WARNING: $MOVIM_HOME is not empty - press Ctrl+C now if this is an error! ..."
		( set -x; ls -A; sleep 10 )
	fi
	copy_movim
elif ! [ "$MOVIM_VERSION" = $(cat CTR_TAG) ]; then
	info "Image version $MOVIM_VERSION does not equal version $(cat CTR_TAG) found in $MOVIM_HOME ..."
	info "- press Ctrl+C now to prevent overriding! ..."
	sleep 10
	info "- overriding now ..."
	copy_movim
fi

# cleanup build files
rm -rf /tmp/movim


# read secrets defined as 'Docker secrets'
secrets_variables='/tmp/variables'
for i in $(env | grep '__FILE')
do
        var_name="$(echo "$i" | sed -e 's|__FILE=| |' | awk '{print $1}')"
        var_file="$(echo "$i" | sed -e 's|__FILE=| |' | awk '{print $2}')"
        echo "$var_name=$(cat $var_file)" >> "$secrets_variables"
done

if [ -f "$secrets_variables" ]
then
        set -a
        source "$secrets_variables"
        set +a
        rm "$secrets_variables"
fi

### wait for database server to be available
info 'Test database server connection ...'
db_test_script='/tmp/db-test.php'

create_db_test_script "$db_test_script"

db_connection="$(php "$db_test_script" | awk '{{print $NF}}')"

if [ $db_connection = 'SUCCESS' ]
then
    info 'Connected! ...'
else
    echo -n 'Wait for database connection ...'
    while true
    do
        db_connection="$(php "$db_test_script" | awk '{{print $NF}}')"
        if [ $db_connection = 'SUCCESS' ]
        then
            info 'Connected! ...'
            break
        else
            sleep 1.5
            echo -n '.'
        fi
    done
fi

rm -f "$db_test_script"

### Initialize/migrate movim database
info 'Initialize/migrate movim database ...'
php vendor/bin/phinx migrate

info 'Start php-fpm ...'
php-fpm --daemonize

sleep 5

info 'Start movim daemon ...'
exec "$@"
