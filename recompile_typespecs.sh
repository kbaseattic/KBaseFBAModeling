#!/bin/sh
# Remove \CR endings if they are present
if [ `command -v dos2unix 2>/dev/null` ]; then
    dos2unix fbaModelServices.spec
    dos2unix fbaModelData.spec
    dos2unix fbaModelCLI.spec
    dos2unix workspaceDocumentDB.spec
fi
# Compile fbaModelServices (legacy setup)
base=fbaModelServices
compile_typespec                \
    -impl ${base}Impl           \
    -service ${base}Server      \
    -psgi ${base}.psgi          \
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
# Complie fbaModelCLI
db_base=Bio::KBase::fbaModel::CLI
compile_typespec                \
    -impl $db_base::Impl        \
    -service $db_base::Service  \
    -psgi fbaModelCLI.psgi      \
    -client $db_base            \
    -js fbaModelCLI             \
    -py fbaModelCLI             \
    fbaModelCLI.spec lib
# Compile workspaceDocumentDB
db_base=Bio::KBase::fbaModel::Workspaces
compile_typespec                \
    -impl $db_base::Impl        \
    -service $db_base::Service  \
    -psgi workspaceDocumentDB.psgi      \
    -client $db_base            \
    -js workspaceDocumentDB     \
    -py workspaceDocumentDB     \
    workspaceDocumentDB.spec lib


