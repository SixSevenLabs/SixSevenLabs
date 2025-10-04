#!/usr/bin/env bash
# assumed to be ran from project root
set -e

lambdas_dir="backend/"
output_dir="infra/terraform/tmp/lambda"

output_dir_abs="$(pwd)/$output_dir"

# cleanup old packaged lambdas in output dir
rm -rf "$output_dir"
mkdir -p "$output_dir"

for dir in "$lambdas_dir"*/; do
  if [ -d "$dir" ]; then
    lambda_name=$(basename "$dir")
    zip_file="$output_dir_abs/${lambda_name}.zip"

    if [ -f "$dir/go.mod" ]; then
        echo "Packaging Go Lambda: $lambda_name"
        # build go binary
        (cd "$dir" && GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap main.go)
        # zip to output dir
        (cd "$dir" && zip -j "$zip_file" bootstrap)
        # cleanup binary in source dir
        rm "$dir/bootstrap"
        echo "    $lambda_name.zip created."
    elif [ -f "$dir/requirements.txt" ]; then
        echo "Packaging Python Lambda: $lambda_name"
        # temp build dir for dependencies
        build_dir=$(mktemp -d)
        echo "    Installing dependencies to $build_dir"
        # Use a virtual environment or --ignore-installed to avoid conflicts
        python3 -m pip install -r "$dir/requirements.txt" -t "$build_dir" --quiet --ignore-installed
        # copy src files
        cp "$dir/"*.py "$build_dir/" 2>/dev/null || true
        cp "$dir/"*.json "$build_dir/" 2>/dev/null || true
        # download spaCy model if needed (for augmentor lambda)
        if grep -q "spacy" "$dir/requirements.txt" && ! grep -q "en_core_web_sm" "$dir/requirements.txt"; then
            echo "        Downloading spaCy model..."
            python3 -m spacy download en_core_web_sm -t "$build_dir" --quiet
        fi
        # create zip from build directory
        (cd "$build_dir" && zip -r "$zip_file" . -q)
        # cleanup temp build dir
        rm -rf "$build_dir"
        echo "    $lambda_name.zip created."
    else
        echo "Skipping $lambda_name: No recognized entry point (main.go or requirements.txt)."
    fi
  fi
done

echo ""
echo "All Lambdas packaged to $output_dir"
ls -lh "$output_dir"/*.zip 2>/dev/null || echo "No packages created"