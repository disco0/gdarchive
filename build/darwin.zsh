#!/usr/bin/env zsh

local dylib_base_name="libgodot_archive_rust"
local dylib_file="${dylib_base_name}.dylib"

local -a base_arches=( x86_64 aarch64 )

local -A targets=(
    [release]=release
    [debug]=debug
)
local target=${targets[release]}

local -a darwin_cargo_targets=(
    ${(@)^base_arches}"-apple-darwin"
)
local -a darwin_make_targets=(
    "build-"${(@)^darwin_cargo_targets}"-${targets[$target]}"
)

local cargo_target_dir=${CARGO_TARGET_DIR:-"${TMPDIR}/godot-archive-rust-target"}

local build_base_dir="./lib"

local universal_target='universal'
local universal_output_path="${build_base_dir}/${universal_target}-apple-darwin"
local universal_lib_path="${universal_output_path}/${dylib_file}"

local gdnative_bin_dir_base="./godot/gdnative/gdarchive/bin"
local gdnative_bin_dir="${gdnative_bin_dir_base}/darwin-${universal_target}"
local godot_project_dylib_path="${gdnative_bin_dir}/${dylib_file}"

function fprint()
{
    builtin print -Pu2 -- ${(@)^@}
}

function print-err()
{
    builtin print -Pu2 "%F{1}"${(@)^@}"%f"
}

function setup-build()
{
    if [[ ! -d ${gdnative_bin_dir} ]]
    then
        command mkdir -p $gdnative_bin_dir || {
            print-err "  Failed to create project gdnative output dir %U%B%{${gdnative_bin_dir}%}%u%b"
            return 1
        }
    fi
    if [[ ! -d ${universal_output_path} ]]
    then
        command mkdir -p $universal_output_path || {
            print-err "  Failed to create universal build dir %U%B%{${universal_output_path}%}%u%b"
            return 1
        }
    fi
    if [[ ! -d ${cargo_target_dir} ]]
    then
        command mkdir -p $cargo_target_dir || {
            print-err "  Failed to create cargo target dir %U%B%{${cargo_target_dir}%}%u%b"
            return 1
        }
    fi

    export CARGO_TARGET_DIR="${cargo_target_dir}"
}

function build-darwin-dylibs()
{
    fprint "\n%F{32}%B%U%{${0}%}%u%b%f"

    foreach darwin_target_name ( $^darwin_cargo_targets )
        fprint "  %F{32}-> %B%U%{${darwin_target_name}%}%u%b%f"
        command cargo build --target $darwin_target_name --$target || {
            print-err "  Build %U%B%{${darwin_target_name}%}%u%b failed."
            return 2
        }

        local build_path="$cargo_target_dir/$darwin_target_name/$target/$dylib_file"
        local out_dir="${build_base_dir}/${darwin_target_name}/"

        [[ -f $build_path ]] || {
            print-err "  Build %U%B%{${darwin_target_name}%}%u%b not found at expected path: %U%B%{${build_path}%}%u%b"
            return 3
        }

        fprint "\n%F{32}cp %B%U%{${build_path}%}%u%b%f %B%U%{${out_dir}%}%u%b%f"
        command cp -v $build_path $out_dir || {
            print-err "  Copying %B%U%{${build_path}%}%u%b failed."
        }
    end
}

function codesign-force()
{
    fprint "\n%F{32}%B%U%{${0}%}%u%b%f"
    foreach codesign_target ( "${(@)^@}" )
        fprint " -> %F{32}%B%U%{${codesign_target}%}%u%b%f"
        command codesign --force --deep --sign - ${codesign_target} || {
            print-err "  Error codesigning %U%B%{${codesign_target}%}%u%b."
            return 3
        }
    end
}

function codesign-darwin-dylibs()
{
    fprint "\n%F{32}%B%U%{${0}%}%u%b%f"

    codesign-force ${build_base_dir}/*apple-darwin/${dylib_file}
}

function build-darwin-universal()
{
    fprint "\n%F{32}%B%U%{${0}%}%u%b%f"

    local -a lipo_args=(
        "${build_base_dir}/"${(@)^base_arches}"-apple-darwin/${dylib_file}"
        -output ${universal_lib_path}
        -create
    )
    command lipo $^lipo_args || {
        print-err "  Error building universal binary to %U%B%{${universal_lib_path}%}%u%b."
        return 4
    }
    # lipo -info ${universal_lib_path}
}

function copy-darwin-universal()
{
    fprint "\n%F{32}%B%U%{${0}%}%u%b%f"

    command cp -vf "${universal_lib_path}" "${godot_project_dylib_path}" || {
        print-err "Failed copy to test project gdnative path %U%B%{${godot_project_dylib_path}%}%u%b"
        return 5
    }

    codesign-force "${godot_project_dylib_path}"
}

setup-build \
    && build-darwin-dylibs    \
    && build-darwin-universal \
    && copy-darwin-universal  \
    && codesign-darwin-dylibs