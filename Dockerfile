#
#FROM centos:latest - some users reported problems with yum
FROM centos:7
MAINTAINER Dave Gill <gill@ucar.edu>

ENV WRF_VERSION 4.0.3
ENV WPS_VERSION 4.0.2
ENV NML_VERSION 4.0.2

# Set up base OS environment

RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-Base.repo && \
    sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Base.repo && \
    yum -y update


RUN yum -y install scl file gcc gcc-gfortran gcc-c glibc.i686 libgcc.i686 libpng-devel jasper \
  jasper-devel hostname m4 make perl tar bash tcsh time wget which zlib zlib-devel \
  openssh-clients openssh-server net-tools fontconfig libgfortran libXext libXrender \
  ImageMagick sudo epel-release git

# Newer version of GNU compiler, required for WRF 2003 and 2008 Fortran constructs

# Install SCL release and drop the broken sclo-sclo repo
RUN yum -y install centos-release-scl && \
    rm -f /etc/yum.repos.d/CentOS-SCLo-sclo.repo && \
    for f in /etc/yum.repos.d/CentOS-SCLo-*.repo; do \
      if [ -f "$f" ]; then \
        sed -i 's|^mirrorlist=|#mirrorlist=|g' "$f"; \
        sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' "$f"; \
        sed -i 's|^baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' "$f"; \
        sed -i 's|^#baseurl=http://mirrorlist.centos.org|baseurl=http://vault.centos.org|g' "$f"; \
        sed -i 's|^baseurl=http://mirrorlist.centos.org|baseurl=http://vault.centos.org|g' "$f"; \
      fi; \
    done

# install devtoolset‑8 and its helpers,
# skipping the broken centos-sclo-sclo repo entirely
RUN yum --disablerepo=centos-sclo-sclo -y install \
      yum-utils \
      scl-utils \
      devtoolset-8 \
      devtoolset-8-gcc \
      devtoolset-8-gcc-gfortran \
      devtoolset-8-gcc-c \
  && yum clean all

RUN groupadd wrf -g 9999
RUN useradd -u 9999 -g wrf -G wheel -M -d /wrf wrfuser
RUN mkdir /wrf \
 &&  chown -R wrfuser:wrf /wrf \
 &&  chmod 6755 /wrf

# Build the libraries with a parallel Make
ENV J 4

# Build OpenMPI under devtoolset-8
RUN mkdir -p /wrf/libs/openmpi/BUILD_DIR && \
    scl enable devtoolset-8 -- bash -c "\
      cd /wrf/libs/openmpi/BUILD_DIR && \
      curl -L -O https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.0.tar.gz && \
      tar -xf openmpi-4.0.0.tar.gz && \
      cd openmpi-4.0.0 && \
      ./configure --prefix=/usr/local &> /wrf/libs/build_log_openmpi_config && \
      make -j${J} &> /wrf/libs/build_log_openmpi_make && \
      make install &>> /wrf/libs/build_log_openmpi_make && \
      cd / && \
      rm -rf /wrf/libs/openmpi/BUILD_DIR"

# Build HDF5 under devtoolset-8 (clone official GitHub tag)
RUN mkdir -p /wrf/libs/hdf5/BUILD_DIR && \
    scl enable devtoolset-8 -- bash -c "\
      cd /wrf/libs/hdf5/BUILD_DIR && \
      git clone --branch hdf5-1_10_4 --depth 1 https://github.com/HDFGroup/hdf5.git hdf5-1_10_4 && \
      cd hdf5-1_10_4 && \
      ./configure --enable-fortran --enable-cxx --prefix=/usr/local &> /wrf/libs/build_log_hdf5_config && \
      make -j${J} &> /wrf/libs/build_log_hdf5_make && \
      make install &>> /wrf/libs/build_log_hdf5_make && \
      rm -rf /wrf/libs/hdf5/BUILD_DIR"

# prerequisites for netCDF builds (skip the broken sclo-sclo repo)
RUN yum --disablerepo=centos-sclo-sclo -y install libcurl-devel zlib-devel

# set NETCDF path and make sure its BUILD_DIR exists
ENV NETCDF=/wrf/libs/netcdf
# Make nc-config visible to configure
ENV PATH=${NETCDF}/bin:$PATH
RUN mkdir -p ${NETCDF}/BUILD_DIR

# download both C and Fortran sources
RUN curl -L -o ${NETCDF}/BUILD_DIR/netcdf-c-4.6.2.tar.gz \
      https://github.com/Unidata/netcdf-c/archive/v4.6.2.tar.gz && \
    curl -L -o ${NETCDF}/BUILD_DIR/netcdf-fortran-4.4.5.tar.gz \
      https://github.com/Unidata/netcdf-fortran/archive/v4.4.5.tar.gz


# Install netCDF‑Fortran from EPEL (matches your netCDF‑C install)
RUN yum --disablerepo=centos-sclo-sclo -y install \
      netcdf-fortran-devel.x86_64 \
      netcdf-fortran.x86_64 && \
    yum clean all



RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

RUN mkdir -p  /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput \
 &&  chown -R wrfuser:wrf /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local \
 &&  chmod 6755 /wrf /wrf/WPS_GEOG /wrf/wrfinput /wrf/wrfoutput /usr/local

# Install NCL from EPEL
RUN yum --disablerepo=centos-sclo-sclo -y install ncl && \
    yum clean all
ENV NCARG_ROOT=/usr

# Set environment for interactive container shells
RUN echo export LDFLAGS="-lm" >> /etc/bashrc \
 && echo export NETCDF=${NETCDF} >> /etc/bashrc \
 && echo export JASPERINC=/usr/include/jasper/ >> /etc/bashrc \
 && echo export JASPERLIB=/usr/lib64/ >> /etc/bashrc \
 && echo export LD_LIBRARY_PATH="/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/bashrc  \
 && echo export PATH=".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/bashrc

RUN echo setenv LDFLAGS "-lm" >> /etc/csh.cshrc \
 && echo setenv NETCDF "${NETCDF}" >> /etc/csh.cshrc \
 && echo setenv JASPERINC "/usr/include/jasper/" >> /etc/csh.cshrc \
 && echo setenv JASPERLIB "/usr/lib64/" >> /etc/csh.cshrc \
 && echo setenv LD_LIBRARY_PATH "/opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}" >> /etc/csh.cshrc \
 && echo setenv PATH ".:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH" >> /etc/csh.cshrc

RUN mkdir /wrf/.ssh ; echo "StrictHostKeyChecking no" > /wrf/.ssh/config
COPY default-mca-params.conf /wrf/.openmpi/mca-params.conf
RUN mkdir -p /wrf/.openmpi
RUN chown -R wrfuser:wrf /wrf/

# all root steps completed above, now below as regular userID wrfuser
USER wrfuser
WORKDIR /wrf

# Download data
ARG argname=tutorial
RUN echo DAVE $argname

# geography (gzip)
RUN if [ "$argname" = "tutorial" ] ; then \
      curl -SL --fail http://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz \
        | tar -xzC /wrf/WPS_GEOG ; \
    fi

# Colorado input (may no longer exist at the old URL)
RUN if [ "$argname" = "tutorial" ] ; then \
      if curl -SL --head --fail http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/colorado_march16.new.tar.gz ; then \
        curl -SL http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/colorado_march16.new.tar.gz \
          | tar -xC /wrf/wrfinput ; \
      else \
        echo "WARNING: tutorial Colorado data not found; skipping download. Please add /wrf/wrfinput/colorado_march16.new.tar.gz manually if needed." ; \
      fi ; \
    fi

# namelists (gzip)
RUN if [ "$argname" = "tutorial" ] ; then \
      curl -SL --fail http://www2.mmm.ucar.edu/wrf/src/namelists_v${NML_VERSION}.tar.gz \
        | tar -xzC /wrf/wrfinput ; \
    fi

# NCL scripts (gzip)
RUN if [ "$argname" = "tutorial" ] ; then \
      if curl -SL --head --fail http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/WRF_NCL_scripts.tar.gz; then \
        curl -SL http://www2.mmm.ucar.edu/wrf/TUTORIAL_DATA/WRF_NCL_scripts.tar.gz \
          | tar -xzC /wrf ; \
      else \
        echo "WARNING: WRF_NCL_scripts.tar.gz not found; skipping."; \
      fi ; \
    fi

# regression test data (plain tar)
RUN if [ "$argname" = "regtest" ] ; then \
      curl -SL --fail http://www2.mmm.ucar.edu/wrf/dave/DATA/Data_small/data_SMALL.tar.gz \
        | tar -xC /wrf ; \
    fi
RUN if [ "$argname" = "regtest" ] ; then \
      curl -SL --fail http://www2.mmm.ucar.edu/wrf/dave/nml.tar.gz \
        | tar -xC /wrf ; \
    fi
RUN if [ "$argname" = "regtest" ] ; then \
      curl -SL --fail http://www2.mmm.ucar.edu/wrf/dave/script.tar \
        | tar -xC /wrf ; \
    fi


# Download wps source
RUN if [ "$argname" = "tutorial" ] ; then git clone https://github.com/wrf-model/WPS.git WPS ; fi

RUN echo _HERE1_
# Pull WRF into /wrf/WRF and apply PR merge
RUN git clone https://github.com/davegill/WRF.git /wrf/WRF && \
    cd /wrf/WRF && \
    git fetch origin +refs/pull/4/merge:FETCH_HEAD && \
    git checkout -qf FETCH_HEAD
RUN echo _HERE2_

ENV JASPERINC /usr/include/jasper
ENV JASPERLIB /usr/lib64
ENV NETCDF_classic 1
ENV LD_LIBRARY_PATH /opt/rh/devtoolset-8/root/usr/lib/gcc/x86_64-redhat-linux/8:/usr/lib64/openmpi/lib:${NETCDF}/lib:${LD_LIBRARY_PATH}
ENV PATH  .:/opt/rh/devtoolset-8/root/usr/bin:/usr/lib64/openmpi/bin:${NETCDF}/bin:$PATH

RUN ssh-keygen -f /wrf/.ssh/id_rsa -t rsa -N '' \
    && chmod 600 /wrf/.ssh/config \
    && chmod 700 /wrf/.ssh \
    && cp /wrf/.ssh/id_rsa.pub /wrf/.ssh/authorized_keys

VOLUME /wrf
CMD ["/bin/tcsh"]
#
