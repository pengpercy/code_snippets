import re
import os


def escape_argument(arg):
    # Escape the argument for the cmd.exe shell.
    # See https://docs.microsoft.com/zh-cn/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
    #
    # First we escape the quote chars to produce a argument suitable for
    # CommandLineToArgvW. We don't need to do this for simple arguments.

    if not arg or re.search(r'(["\s])', arg):
        arg = '"' + arg.replace('"', r'\"') + '"'

    return escape_for_cmd_exe(arg)


def escape_for_cmd_exe(arg):
    # Escape an argument string to be suitable to be passed to
    # cmd.exe on Windows
    #
    # This method takes an argument that is expected to already be properly
    # escaped for the receiving program to be properly parsed. This argument
    # will be further escaped to pass the interpolation performed by cmd.exe
    # unchanged.
    #
    # Any meta-characters will be escaped, removing the ability to e.g. use
    # redirects or variables.
    #
    # @param arg [String] a single command line argument to escape for cmd.exe
    # @return [String] an escaped string suitable to be passed as a program
    #   argument to cmd.exe

    meta_chars = '()%!^"<>&|'
    meta_re = re.compile('(' + '|'.join(re.escape(char)
                                        for char in list(meta_chars)) + ')')
    print(meta_re)
    meta_map = {char: "^%s" % char for char in meta_chars}
    print(meta_map)
    def escape_meta_chars(m):
        char = m.group(1)
        return meta_map[char]

    return meta_re.sub(escape_meta_chars, arg)


if __name__ == "__main__":
    print(escape_argument('''^(some arg^^ with spaces'''))
    CMD = '''string with spaces and &weird^ charcters!'''
    os.system(
        'python -c "import sys; print(sys.argv[1])" {0}'.format(escape_argument(CMD)))
    # string with spaces and &weird^ charcters!
    pass
