#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/compare_tree.log"

GD_TREE_FILE="$MAIN/temp/.google_drive_files"
ROOT_TREE_FILE="$MAIN/temp/.ROOT_tree"
GD_FOLDERS_FILE="$MAIN/temp/.google_drive_folders"
ROOT_FOLDERS_FILE="$MAIN/temp/.ROOT_folders"
TO_CREATE_FILE="$MAIN/temp/.files_to_create"
TO_UPDATE_FILE="$MAIN/temp/.files_to_update"
TO_DELETE_FILE="$MAIN/temp/.files_to_delete"
FOLDERS_TO_CREATE_FILE="$MAIN/temp/.folders_to_create"
FOLDERS_TO_DELETE_FILE="$MAIN/temp/.folders_to_delete"

main() {
    local error_message=""

    log_message "ファイルとフォルダの比較を開始します。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            # Create temp directory if it doesn't exist
            mkdir -p "$(dirname "$TO_CREATE_FILE")"

            # Initialize files
            >"$TO_CREATE_FILE"
            >"$TO_UPDATE_FILE"
            >"$TO_DELETE_FILE"
            >"$FOLDERS_TO_CREATE_FILE"
            >"$FOLDERS_TO_DELETE_FILE"

            # Compare folders to create
            awk '
            BEGIN {
                FS=" ";
            }
            NR==FNR {
                if ($0 != "") root_folders[$1] = $2;
                next;
            }
            {
                if ($0 != "") gd_folders[$1] = $2;
            }
            END {
                for (folder in root_folders) {
                    if (!(folder in gd_folders)) {
                        print folder, root_folders[folder] > "'"$FOLDERS_TO_CREATE_FILE"'";
                    }
                }
            }
            ' "$ROOT_FOLDERS_FILE" "$GD_FOLDERS_FILE"

            # Compare folders to delete
            awk '
            BEGIN {
                FS=" ";
            }
            NR==FNR {
                if ($0 != "") gd_folders[$1] = $2;
                next;
            }
            {
                if ($0 != "") root_folders[$1] = $2;
            }
            END {
                for (folder in gd_folders) {
                    if (!(folder in root_folders)) {
                        print folder, gd_folders[folder] > "'"$FOLDERS_TO_DELETE_FILE"'";
                    }
                }
            }
            ' "$GD_FOLDERS_FILE" "$ROOT_FOLDERS_FILE"

            # Compare files to create
            awk '
            BEGIN {
                FS=" ";
            }
            NR==FNR {
                if ($0 != "") root_files[$1] = $2 " " $3;
                next;
            }
            {
                if ($0 != "") gd_files[$1] = $2 " " $3;
            }
            END {
                for (file in root_files) {
                    if (!(file in gd_files)) {
                        print file, root_files[file] > "'"$TO_CREATE_FILE"'";
                    }
                }
            }
            ' "$ROOT_TREE_FILE" "$GD_TREE_FILE"

            # Compare files to update
            awk '
            BEGIN {
                FS=" ";
            }
            NR==FNR {
                if ($0 != "") root_files[$1] = $2 " " $3;
                next;
            }
            {
                if ($0 != "") gd_files[$1] = $2 " " $3;
            }
            END {
                for (file in root_files) {
                    if (file in gd_files && root_files[file] > gd_files[file]) {
                        print file, gd_files[file] > "'"$TO_UPDATE_FILE"'";
                    }
                }
            }
            ' "$ROOT_TREE_FILE" "$GD_TREE_FILE"

            # Compare files to delete
            awk '
            BEGIN {
                FS=" ";
            }
            NR==FNR {
                if ($0 != "") {
                    gd_files[$1] = $2 " " $3;
                }
                next;
            }
            {
                if ($0 != "") root_files[$1] = $2 " " $3;
            }   
            END {
                for (file in gd_files) {
                    if (!(file in root_files)) {
                        print file, gd_files[file] > "'"$TO_DELETE_FILE"'";
                    }
                }
            }
            ' "$GD_TREE_FILE" "$ROOT_TREE_FILE"

            # Check if any of the output files are empty
            if [ ! -s "$TO_CREATE_FILE" ] && [ ! -s "$TO_UPDATE_FILE" ] && [ ! -s "$TO_DELETE_FILE" ] &&
                [ ! -s "$FOLDERS_TO_CREATE_FILE" ] && [ ! -s "$FOLDERS_TO_DELETE_FILE" ]; then
                echo "比較結果: 変更なし"
            else
                echo "比較結果:"
                echo "作成するファイル数: $(wc -l <"$TO_CREATE_FILE")"
                echo "更新するファイル数: $(wc -l <"$TO_UPDATE_FILE")"
                echo "削除するファイル数: $(wc -l <"$TO_DELETE_FILE")"
                echo "作成するフォルダ数: $(wc -l <"$FOLDERS_TO_CREATE_FILE")"
                echo "削除するフォルダ数: $(wc -l <"$FOLDERS_TO_DELETE_FILE")"
            fi
        } 2>&1
    ) || {
        echo "ファイルとフォルダの比較中にエラーが発生しました：$error_message"
        return 1
    }

    log_message "ファイルとフォルダの比較が成功しました。"
    log_message "$error_message"
    return 0
}

# Call the main function and capture its exit status
main
exit $?
