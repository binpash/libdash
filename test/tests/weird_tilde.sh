case $nm_file_list_spec~$to_tool_file_cmd in
                *~func_convert_file_noop | *~func_convert_file_msys_to_w32 | ~*)
                  try_normal_branch=yes
                  eval cmd=\"$cmd1\"
                  func_len " $cmd"
                  len=$func_len_result
                  ;;
                *)
                  try_normal_branch=no
                  ;;
              esac
