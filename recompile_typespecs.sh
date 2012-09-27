#!/bin/sh
# Compile fbaModelServices (legacy setup)
base=fbaModelServices
compile_typespec                \
    -impl ${base}Impl           \
    -service ${base}Server      \
    -psgi fbaModelData.psgi     \
    -client ${base}Client       \
    -js ${base}Client           \
    -py ${base}Client           \
    fbaModelServices.spec lib
# Complie fbaModelData
db_base=Bio::KBase::fbaModel::Data
compile_typespec                \
    -impl $db_base::Impl        \
    -service $db_base::Service  \
    -psgi fbaModelData.psgi     \
    -client $db_base            \
    -js fbaModelData            \
    -py fbaModelData            \
    fbaModelData.spec lib


