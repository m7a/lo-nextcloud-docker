<?php
# Due to this bug we need to wait for the DB to become online:
# https://help.nextcloud.com/t/failed-to-install-nextcloud-with-docker-compose/83681

error_reporting(E_ALL | E_NOTICE);

while(TRUE) {
	try {
		$db = new PDO("pgsql:host=postgres;port=5432;dbname=nextcloud",
				"nextcloud", getenv("POSTGRES_PASSWORD"),
				[PDO::ATTR_PERSISTENT => 0,
				PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
		$db->query("SELECT 1");
	} catch(Exception $e) {
		echo(".");
		sleep(1);
		continue;
	};
	break;
}

echo("\n");
pcntl_exec("/entrypoint.sh", ["php-fpm"]);

?>
