# Docker Container for WRF (Updated Version)

This containerized environment for the Weather Research and Forecasting (WRF) modeling system was modernized and extended by **Boyuan (Keven) Guan** as part of the **FIU EnviStor project**.

The original Docker configuration was provided by *John Exby* and *Kate Fossell*. From their work, this updated version introduces several fixes and enhancements to support updated dependencies and robust use in modern Linux-based systems.

---

## 🔧 Enhancements in This Version

- Fixed failing downloads due to deprecated or moved URLs.
- Replaced `tar -xz` with `tar -x` for misidentified gzip formats.
- Verified all tutorial and regression test data availability with `curl --head` before attempting download.
- Ensured `netcdf-fortran` compiles properly by aligning environment variables and linking order.
- Replaced legacy `ENV key value` syntax with modern `ENV key=value` in Dockerfile.
- Recovered broken dependency links from official mirrors and GitHub.
- Verified tutorial builds end-to-end and support interactive sessions in container.
- Added attribution and version control support under Keven's GitHub fork.

---

## 📦 Included in the Container

- Source code for **WRF** and **WPS** from GitHub
- External libraries required for WRF and WPS
- CentOS 7-based OS image with traditional user-level Linux capabilities
- GNU Compiler support via `devtoolset-8`
- OpenMPI for distributed memory execution
- NCL for post-processing WRF output (PDF support)
- Static low-resolution data for `geogrid`
- Two Dockerfiles:
  - `Dockerfile_tutorial`
  - `Dockerfile_regtest`
- Sample data and scripts for:
  - Running the WRF Tutorial case
  - Executing regression tests via script

---

## 🔀 Choose a Dockerfile

Depending on the use case, link the appropriate Dockerfile:
```bash
ln -sf Dockerfile_tutorial Dockerfile
# or
ln -sf Dockerfile_regtest Dockerfile
```

---

## 🚀 Tutorial Case

The [README_tutorial.md](README_tutorial.md) provides full step-by-step instructions to run the WRF model:

```bash
docker build -t wrf_tutorial .
mkdir OUTPUT
docker run -it --name teachme -v `pwd`/OUTPUT:/wrf/wrfoutput wrf_tutorial /bin/tcsh
```

---

## 🧪 Regression Test Case

This case is designed to validate code correctness and performance across model configurations.

```bash
docker build -t wrf_regtest .
docker run -d -t --name test_001 wrf_regtest /bin/tcsh
docker exec test_001 ./script.csh BUILD CLEAN 34 1 em_real -d
docker exec test_001 ./script.csh RUN em_real 34 em_real 03
docker stop test_001
```

Check that both `docker exec` commands return exit status `0`.

Additional test configurations are described in [README_regtest.md](README_regtest.md).

---

## 📚 Acknowledgments

This updated version is maintained under the forked repository by **Keven Guan**, Florida International University, 2025. Contributions welcome under [Keven1894/WRF_DOCKER](https://github.com/Keven1894/WRF_DOCKER).
