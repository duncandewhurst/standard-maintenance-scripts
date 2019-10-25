set -e

# Python dependencies
pip install flake8 json-merge-patch jsonref jsonschema 'pytest>=3.6' requests rfc3987 strict-rfc3339

# Ruby dependencies
gem install mdl
