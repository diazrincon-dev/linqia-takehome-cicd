# CI/CD Solution Design

This document outlines the architecture, workflows, and artifacts of the CI/CD solution for the sample project. The implementation is based on GitHub Actions, using `CI` and `CD` workflows along with the required Docker build files.

---

## Goals

* Validate linting and test execution across multiple Python versions (3.10, 3.11, 3.12).
* Generate a test coverage report and store it as an artifact.
* Build and publish a Docker image to Docker Hub, tagged with branch and commit SHA.
* Post a pull request comment including:

  * Link to the built image
  * Test results and coverage summary
  * Links to artifacts
* Perform a mock deployment after successful CI by running the Docker container in the GitHub runner and commenting the result back on the PR.

---

## Workflow Architecture

### CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**

* `push` to `main`
* `pull_request` targeting `main`

**Jobs:**

* **`lint_test_matrix`**

  * Strategy: matrix across Python 3.10, 3.11, 3.12
  * Runs `ruff` linter and `pytest` (without coverage)
  * Uploads JUnit test reports per Python version

* **`coverage`**

  * Executes tests with coverage on Python 3.12
  * Produces `coverage.xml`, `junit.xml`
  * Exposes coverage percentage and test totals as job outputs and artifacts

* **`build_and_push`**

  * Builds Docker image and pushes to Docker Hub
  * Tags: sanitized branch name (`:<ref>`) and commit SHA (`:<sha>`)
  * Runs image vulnerability scan using Trivy (non-blocking)

* **`pr_comment`**

  * Posts a PR comment summarizing:

    * Docker Hub image link (branch tag)
    * Coverage metrics
    * Test totals
    * Direct link to the workflow run and artifacts

---

### CD Workflow (`.github/workflows/cd.yml`)

**Trigger:**

* `workflow_run` from the `CI` workflow with `conclusion == success`

**Steps:**

* Pulls the Docker image tagged with the branch (fallback to SHA if branch tag unavailable)
* Runs the container (`docker run <image> 2 3`) to simulate deployment
* On PR events, posts a comment with deployment simulation results

---

## Docker Image

* Based on `python:3.12-slim`
* Copies the `sample_app` package
* Defines entrypoint:

  ```yaml
  ENTRYPOINT ["python", "-m", "sample_app"]
  ```
* Mock CD run executes:

  ```bash
  docker run <image> 2 3
  ```

  Expected output: `5`

---

## Secrets and Configuration

**Required variables** (Settings → Secrets and variables → Actions):

* `DOCKERHUB_USERNAME` – Docker Hub username

**Required secrets** (Settings → Secrets and variables → Actions):

* `DOCKERHUB_TOKEN` – Docker Hub password or access token

**Optional variables** (Settings → Secrets and variables → Actions → Variables):

* `DOCKERHUB_REPO` – Full repository path (`user/repo`).

  * Defaults to: `${DOCKERHUB_USERNAME}/linqia-takehome-cicd`

**Generated image tags:**

* `:<ref>` → sanitized branch name (`feature-x`, `main`, etc.)
* `:<sha>` → commit SHA for traceability

**Examples:**

```bash
docker pull $DOCKERHUB_REPO:main
docker pull $DOCKERHUB_REPO:<sha>
```

---

## Quality Gates and Artifacts

* **Linting:** `ruff check .`

* **Tests:**

  * `pytest` with JUnit output for each Python version
  * Coverage generated on Python 3.12 (`coverage.xml`)

* **Artifacts uploaded:**

  * JUnit results per version
  * `coverage.xml`
  * `coverage.txt` (coverage percentage)

* **Pull request comment includes:**

  * Docker Hub link (branch-tagged image)
  * Coverage percentage
  * Total test count
  * Link to workflow run and downloadable artifacts

* **Bonus:** Docker image scanned with `aquasecurity/trivy-action` (HIGH/CRITICAL severities only, non-blocking).

---

## Trade-offs and Future Improvements

* Coverage is only calculated on Python 3.12 to simplify aggregation.

  * For multi-version coverage aggregation, an additional job can merge results.
* Artifact links point to the workflow run (stable URLs).

  * Direct artifact links are ephemeral.
* No coverage threshold enforced by default.

  * Can be added (e.g., fail if coverage `< 80%`).
* Potential enhancements:

  * Image signing with `cosign`
  * SBOM generation and publication with `syft`

---

## Usage Instructions

1. Configure `DOCKERHUB_USERNAME`variable and `DOCKERHUB_TOKEN` secret for the repository.
2. (Optional) Define `DOCKERHUB_REPO` in repository variables (`user/repo`). Defaults to `${DOCKERHUB_USERNAME}/linqia-takehome-cicd`.
3. Open a pull request or push to `main`.

   * The CI workflow will build, test, publish the Docker image, and comment on the PR.
4. Upon successful CI completion, the CD workflow will:

   * Pull the published image
   * Run a mock deployment (`docker run`)
   * Post deployment results as a PR comment (if applicable)
