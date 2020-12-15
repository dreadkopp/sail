#!/bin/sh

UNAMEOUT="$(uname -s)"

WHITE='\033[1;37m'
NC='\033[0m'

APP_SERVICE="slim"

# Verify operating system is supported...
case "${UNAMEOUT}" in
    Linux*)             MACHINE=linux;;
    Darwin*)            MACHINE=mac;;
    *)                  MACHINE="UNKNOWN"
esac

if [ "$MACHINE" == "UNKNOWN" ]; then
    echo "Unsupported operating system [$(uname -s)]. Laravel Sail supports macOS, Linux, and Windows (WSL2)."
fi

if [ "$MACHINE" == "linux" ]; then
    export SEDCMD="sed -i"
elif [ "$MACHINE" == "mac" ]; then
    export SEDCMD="sed -i .bak"
fi

# Ensure that Docker is running...
if ! docker info > /dev/null 2>&1; then
    echo -e "${WHITE}Docker is not running.${NC}"

    exit 1
fi

# Determine if Sail is currently up...
PSRESULT="$(docker-compose ps -q)"

if docker-compose ps | grep 'Exit' &> /dev/null; then
    docker-compose down > /dev/null 2>&1

    EXEC="no"
elif [ -n "$PSRESULT" ]; then
    EXEC="yes"
else
    EXEC="no"
fi

# Function that outputs Sail is not running...
function sail_is_not_running {
    echo -e "${WHITE}Sail is not running.${NC}"
    echo ""
    echo -e "${WHITE}You may Sail using the following commands:${NC} './vendor/bin/sail up' or './vendor/bin/sail up -d'"

    exit 1
}

if [ $# -gt 0 ]; then

    # Proxy PHP commands to the "php" binary on the application container...
    if [ "$1" == "php" ]; then
        shift 1

        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                php "$@"
        else
            sail_is_not_running
        fi

    # Proxy Composer commands to the "composer" binary on the application container...
    elif [ "$1" == "composer" ]; then
        shift 1
        echo "$APP_SERVICE"
        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                composer "$@"
        else
            sail_is_not_running
        fi

    # Proxy Artisan commands to the "artisan" binary on the application container...
    elif [ "$1" == "manage" ]; then
        shift 1

        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                php internal/manage.php "$@"
        else
            sail_is_not_running
        fi

    # Proxy the "test" command to the "php artisan test" Artisan command...
    elif [ "$1" == "test" ]; then
        shift 1

        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                php -dpcov.enabled=1 -dpcov.directory=./../ -dpcov.exclude="~vendor~" /var/www/webshop/vendor/bin/phpunit -c /var/www/webshop/phpunit.xml -d max_execution_time=1200 /var/www/webshop/tests --testdox "$@"
        else
            sail_is_not_running
        fi


    # Proxy the "test" command to the "php artisan test" Artisan command...
    elif [ "$1" == "phinx" ]; then
        shift 1

        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                ./vendor/bin/phinx "$@"
        else
            sail_is_not_running
        fi


    # Initiate a Bash shell within the application container...
    elif [ "$1" == "shell" ]; then
        shift 1

        if [ "$EXEC" == "yes" ]; then
            docker-compose exec \
                -u nginx \
                "$APP_SERVICE" \
                ash
        else
            sail_is_not_running
        fi

    # Pass unknown commands to the "docker-compose" binary...
    else
        docker-compose "$@"
    fi
else
    docker-compose ps
fi
