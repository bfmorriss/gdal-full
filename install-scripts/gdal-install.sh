#!/bin/bash

echo 
echo "Please specify a path to install to:"
read tools

# Logging
date_str="+%Y_%m%d_%H%M%S"
full_date=`date $date_str`
host=$(hostname)
log="output_"$host"_"$full_date.log

exec > >(tee --append $log)
exec 2>&1


# Main install

mkdir -p $tools
case "$tools" in
	/*)
	;;
	*)
	tools=$(pwd)/$tools
	;;
esac

echo "Installing in: "$tools

default="1.10.0"
echo -e "Choose GDAL version ($default): \c"
read gdal_version
[ -z "$gdal_version" ] && gdal_version=$default
echo "Using: gdal $gdal_version"
  
export	PATH=$tools/anaconda/bin:$tools/gdal/bin:$PATH
export	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib

# Install MiniConda Python distribution
# This will build the base directory /tools for all following software

cd $tools && \
wget --no-check-certificate \
http://repo.continuum.io/miniconda/Miniconda-3.7.0-Linux-x86_64.sh && \
bash Miniconda-3.7.0-Linux-x86_64.sh -b -p $tools/anaconda && \
rm -f Miniconda*
echo y | conda install scipy jinja2 conda-build dateutil

# Install conda postgresql client package
vers=0.1
cd $tools && \
wget --no-check-certificate \
https://github.com/minadyn/conda-postgresql-client/archive/$vers.zip && \
unzip $vers && \
conda build conda-postgresql-client-$vers && \
conda install --yes $(conda build conda-postgresql-client-$vers --output) && \
rm -f conda-postgresql-client-$vers

# Install CFITSIO
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/cfitsio/cfitsio3360.tar.gz && \
tar xvfz cfitsio3360.tar.gz && \
cd cfitsio && \
./configure --prefix=$tools/cfitsio --enable-sse2 --enable-ssse3 --enable-reentrant && \
make -j && make install

# GEOS
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/geos/geos-3.4.2.tar.bz2 && \
tar xvfj geos-3.4.2.tar.bz2 && \
cd geos-3.4.2 && \
./configure --prefix=$tools/geos && \
make -j && make install 

# PROJ
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/proj/proj-4.8.0.tar.gz && \
tar xvfz proj-4.8.0.tar.gz && \
cd proj-4.8.0 && \
./configure --prefix=$tools/proj --with-jni=no && \
make -j && make install

# Cmake 2.8
cd $tools &&
wget http://www.cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz && \
tar xvfz cmake-2.8.12.2.tar.gz && \
cd cmake-2.8.12.2 && \
./configure && \
gmake

# OPENJPEG
# Change to cmake or cmake28 depending on what is installed
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/openjpeg/openjpeg-2.0.0.tar.gz && \
tar xvfz openjpeg-2.0.0.tar.gz && \
cd openjpeg-2.0.0 && \
$tools/cmake-2.8.12.2/bin/cmake -DCMAKE_INSTALL_PREFIX=$tools/openjpeg-2 && \
make install

# GDAL
# Parallel make will fail due to race conditions. Do not use -j
# GDAL 1.11 breaks sparse_disp
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"

cd $tools && \
wget --no-check-certificate \
http://download.osgeo.org/gdal/$gdal_version/gdal-$gdal_version.tar.gz && \
tar xvfz gdal-$gdal_version.tar.gz && \
cd gdal-$gdal_version && \
./configure --prefix=$tools/gdal --with-geos=$tools/geos/bin/geos-config --with-cfitsio=$tools/cfitsio --with-pg=$tools/anaconda/bin/pg_config \
--with-python --with-openjpeg=$tools/openjpeg-2 --with-sqlite3=no && \
make && make install && \
cd swig/python && python setup.py install

export	GDAL_DATA=$tools/gdal/share/gdal

echo "export	PATH=$tools/anaconda/bin:$tools/gdal/bin:\$PATH" >> $tools/init-gdal.sh
echo "export	GDAL_DATA=$tools/gdal/share/gdal" >> $tools/init-gdal.sh
echo "export	LD_LIBRARY_PATH=$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib:\$LD_LIBRARY_PATH" >> $tools/init-gdal.sh
echo
echo	"The tools were installed in $tools."
echo	"There is an init script that sets the environment and is installed at $tools/init-gdal.sh. You can source this file to run."
