# Ensure there is a file resource for each element of a directory path
# @param path
#   Absolute directory path
#
function kv_test::ensure_dir_tree(
  Stdlib::AbsolutePath $path
) {

  $dirs = $path[1,-1].split('/').reduce([]) |$memo, $subdir| {
    $_dir =  $memo.empty ? {
        true    => "/${subdir}",
        default => "${$memo[-1]}/${subdir}",
    }
    $memo << $_dir
  }

  ensure_resource('file', $dirs, {ensure => 'directory'})
}
