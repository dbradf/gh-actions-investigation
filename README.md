# GitHub Actions investigation

Recreate issue with GitHub actions double triggering.

## Usage

* Create a PR based off main
* Run the recreate script a few times until 2 CI runs show up.
 * `./recreate.sh $(cat ~/token.txt) dbradf gh-actions-investigation 1 target-branch main`
