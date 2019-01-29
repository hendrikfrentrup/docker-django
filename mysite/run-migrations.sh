!/bin/sh

# Collect static assets
echo "Collect static assets"
python manage.py collectstatic

# Apply database migrations
echo "Apply database migrations"
python manage.py migrate

exit 0