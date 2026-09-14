class LanguageKeywords {
  static const Map<String, List<String>> keywords = {
    'python': [
      'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
      'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
      'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
      'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return',
      'try', 'while', 'with', 'yield',
    ],
    'javascript': [
      'abstract', 'arguments', 'async', 'await', 'boolean', 'break',
      'byte', 'case', 'catch', 'char', 'class', 'const', 'continue',
      'debugger', 'default', 'delete', 'do', 'double', 'else', 'enum',
      'export', 'extends', 'false', 'final', 'finally', 'float', 'for',
      'function', 'goto', 'if', 'implements', 'import', 'in', 'instanceof',
      'int', 'interface', 'let', 'long', 'native', 'new', 'null',
      'package', 'private', 'protected', 'public', 'return', 'short',
      'static', 'super', 'switch', 'synchronized', 'this', 'throw',
      'throws', 'transient', 'true', 'try', 'typeof', 'undefined',
      'var', 'void', 'volatile', 'while', 'with', 'yield',
    ],
    'cpp': [
      'auto', 'break', 'case', 'char', 'const', 'continue', 'default',
      'do', 'double', 'else', 'enum', 'extern', 'float', 'for', 'goto',
      'if', 'inline', 'int', 'long', 'register', 'restrict', 'return',
      'short', 'signed', 'sizeof', 'static', 'struct', 'switch', 'typedef',
      'union', 'unsigned', 'void', 'volatile', 'while',
      '_Bool', '_Complex', '_Imaginary',
      'bool', 'catch', 'class', 'const_cast', 'delete', 'dynamic_cast',
      'explicit', 'false', 'friend', 'mutable', 'namespace', 'new',
      'operator', 'private', 'protected', 'public', 'reinterpret_cast',
      'static_cast', 'template', 'this', 'throw', 'true', 'try', 'typeid',
      'typename', 'using', 'virtual', 'wchar_t',
    ],
    'html': [
      'a', 'abbr', 'address', 'area', 'article', 'aside', 'audio',
      'b', 'base', 'bdi', 'bdo', 'blockquote', 'body', 'br', 'button',
      'canvas', 'caption', 'cite', 'code', 'col', 'colgroup',
      'data', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt',
      'em', 'embed',
      'fieldset', 'figcaption', 'figure', 'footer', 'form',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'hr', 'html',
      'i', 'iframe', 'img', 'input', 'ins',
      'kbd',
      'label', 'legend', 'li', 'link',
      'main', 'map', 'mark', 'menu', 'meta', 'meter',
      'nav', 'noscript',
      'object', 'ol', 'optgroup', 'option', 'output',
      'p', 'picture', 'pre', 'progress',
      'q',
      'rp', 'rt', 'ruby',
      's', 'samp', 'script', 'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strong', 'style', 'sub', 'summary', 'sup',
      'table', 'tbody', 'td', 'template', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track',
      'u', 'ul',
      'var', 'video',
      'wbr',
    ],
    'java': [
      'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch',
      'char', 'class', 'const', 'continue', 'default', 'do', 'double',
      'else', 'enum', 'extends', 'final', 'finally', 'float', 'for',
      'goto', 'if', 'implements', 'import', 'instanceof', 'int',
      'interface', 'long', 'native', 'new', 'package', 'private',
      'protected', 'public', 'return', 'short', 'static', 'strictfp',
      'super', 'switch', 'synchronized', 'this', 'throw', 'throws',
      'transient', 'try', 'void', 'volatile', 'while',
      'true', 'false', 'null',
    ],
  };

  static const Map<String, List<String>> builtins = {
    'python': [
      'print', 'len', 'range', 'input', 'str', 'int', 'float', 'list',
      'dict', 'tuple', 'set', 'bool', 'type', 'isinstance', 'enumerate',
      'zip', 'map', 'filter', 'sorted', 'reversed', 'abs', 'max', 'min',
      'sum', 'round', 'open', 'read', 'write', 'append', 'extend',
      'remove', 'pop', 'insert', 'index', 'count', 'sort', 'reverse',
      'keys', 'values', 'items', 'get', 'update', 'clear', 'copy',
      'startswith', 'endswith', 'split', 'join', 'replace', 'strip',
      'format', 'upper', 'lower', 'find', 'encode', 'decode',
      'Exception', 'ValueError', 'TypeError', 'KeyError', 'IndexError',
      'AttributeError', 'ImportError', 'FileNotFoundError', 'OSError',
      'np.array', 'np.zeros', 'np.ones', 'np.arange', 'np.linspace',
      'np.random', 'np.mean', 'np.sum', 'np.dot', 'np.reshape',
      'np.size', 'np.shape', 'np.dtype', 'np.copy', 'np.where',
      'np concatenate', 'np.stack', 'np.split', 'np.sort', 'np.unique',
      'np.min', 'np.max', 'np.argmin', 'np.argmax', 'np.std', 'np.var',
      'np.sqrt', 'np.exp', 'np.log', 'np.sin', 'np.cos', 'np.tan',
      'np.abs', 'np.round', 'np.floor', 'np.ceil', 'np.astype',
      'pd.DataFrame', 'pd.Series', 'pd.read_csv', 'pd.read_excel',
      'pd.read_json', 'pd.read_sql', 'pd.merge', 'pd.concat',
      'pd.get_dummies', 'pd.to_datetime', 'pd.to_numeric',
      'pd.date_range', 'pd.Categorical', 'pd.cut', 'pd.qcut',
      'df.head', 'df.tail', 'df.shape', 'df.columns', 'df.dtypes',
      'df.describe', 'df.info', 'df.isnull', 'df.dropna', 'df.fillna',
      'df.groupby', 'df.sort_values', 'df.rename', 'df.drop',
      'df.loc', 'df.iloc', 'df.apply', 'df.value_counts', 'df.nunique',
      'df.plot', 'df.to_csv', 'df.to_excel', 'df.copy', 'df.set_index',
      'df.reset_index', 'df.melt', 'df.pivot_table', 'df.stack', 'df.unstack',
    ],
    'javascript': [
      'console', 'log', 'warn', 'error', 'info', 'table',
      'document', 'window', 'navigator', 'location', 'history',
      'setTimeout', 'setInterval', 'clearTimeout', 'clearInterval',
      'fetch', 'JSON', 'parse', 'stringify', 'Array', 'Object',
      'String', 'Number', 'Boolean', 'Date', 'Math', 'RegExp',
      'Map', 'Set', 'Promise', 'async', 'await', 'Symbol',
      'parseInt', 'parseFloat', 'isNaN', 'isFinite',
      'addEventListener', 'removeEventListener', 'querySelector',
      'querySelectorAll', 'getElementById', 'getElementsByClassName',
      'createElement', 'appendChild', 'innerHTML', 'textContent',
      'prototype', 'constructor', 'hasOwnProperty',
      'length', 'push', 'pop', 'shift', 'unshift', 'splice',
      'slice', 'concat', 'join', 'reverse', 'sort', 'map', 'filter',
      'reduce', 'forEach', 'find', 'includes', 'indexOf', 'keys',
      'values', 'entries', 'assign', 'freeze', 'defineProperty',
    ],
    'cpp': [
      'printf', 'scanf', 'malloc', 'calloc', 'realloc', 'free',
      'strlen', 'strcpy', 'strcat', 'strcmp', 'sprintf', 'sscanf',
      'fopen', 'fclose', 'fread', 'fwrite', 'fprintf', 'fscanf',
      'stdin', 'stdout', 'stderr', 'NULL', 'EOF',
      'cout', 'cin', 'cerr', 'endl', 'string', 'vector', 'map',
      'set', 'list', 'queue', 'stack', 'pair', 'tuple',
      'begin', 'end', 'size', 'empty', 'push_back', 'pop_back',
      'insert', 'erase', 'find', 'clear', 'front', 'back',
      'sort', 'reverse', 'swap', 'min', 'max', 'abs',
      'iostream', 'string', 'vector', 'algorithm', 'cmath',
      'cstdio', 'cstring', 'cstdlib', 'ctime',
      'endl', 'std', 'using', 'namespace',
    ],
    'java': [
      'System', 'out', 'println', 'print', 'printf',
      'String', 'Integer', 'Double', 'Float', 'Boolean', 'Long',
      'Character', 'Byte', 'Short', 'Object', 'Class',
      'ArrayList', 'HashMap', 'LinkedList', 'HashSet', 'TreeMap',
      'List', 'Map', 'Set', 'Queue', 'Stack', 'Deque',
      'Collections', 'Arrays', 'Math', 'Random', 'Scanner',
      'Exception', 'RuntimeException', 'IOException', 'NullPointerException',
      'ArrayIndexOutOfBoundsException', 'ClassNotFoundException',
      'Thread', 'Runnable', 'StringBuilder', 'StringBuffer',
      'File', 'FileReader', 'FileWriter', 'BufferedReader', 'BufferedWriter',
      'InputStream', 'OutputStream', 'Serializable', 'Comparable',
      'Override', 'Deprecated', 'SuppressWarnings',
    ],
  };

  static const Map<String, List<String>> snippets = {
    'python': [
      'def function_name():',
      'class ClassName:',
      'if condition:',
      'elif condition:',
      'else:',
      'for i in range():',
      'while condition:',
      'try:',
      'except Exception as e:',
      'with open() as f:',
      'import module',
      'from module import',
      'lambda x: x',
      'list comprehension',
      'print()',
      'return',
      'raise Exception',
      'assert condition',
    ],
    'javascript': [
      'function name() {}',
      'const name = () => {}',
      'class Name {}',
      'if (condition) {}',
      'else if (condition) {}',
      'else {}',
      'for (let i = 0; i < n; i++) {}',
      'for (const item of array) {}',
      'while (condition) {}',
      'try {} catch (e) {}',
      'async function name() {}',
      'await promise',
      'const [a, b] = array',
      'console.log()',
      'return',
      'import {} from ""',
      'export default',
      'try {} finally {}',
    ],
    'cpp': [
      '#include <stdio.h>',
      '#include <stdlib.h>',
      '#include <string.h>',
      'int main() {}',
      'void function() {}',
      'if (condition) {}',
      'else {}',
      'for (int i = 0; i < n; i++) {}',
      'while (condition) {}',
      'do {} while (condition);',
      'switch (value) {}',
      'case value:',
      'struct Name {};',
      'typedef struct {} Name;',
      'malloc(sizeof())',
      'printf("")',
      'scanf("")',
      'return 0',
    ],
    'java': [
      'public class Main {}',
      'public static void main(String[] args) {}',
      'public void method() {}',
      'if (condition) {}',
      'else {}',
      'for (int i = 0; i < n; i++) {}',
      'for (Type item : list) {}',
      'while (condition) {}',
      'try {} catch (Exception e) {}',
      'try {} finally {}',
      'switch (value) {}',
      'case value:',
      'System.out.println()',
      'return',
      'import package;',
      'new ClassName()',
      '@Override',
      'interface Name {}',
    ],
  };

  static Map<String, List<String>> getCompletionWords(String language) {
    final words = <String>{};
    if (keywords.containsKey(language)) words.addAll(keywords[language]!);
    if (builtins.containsKey(language)) words.addAll(builtins[language]!);
    if (snippets.containsKey(language)) words.addAll(snippets[language]!);
    return {language: words.toList()..sort()};
  }

  static List<String> getSuggestions(String language, String prefix) {
    final allWords = <String>{};
    if (keywords.containsKey(language)) allWords.addAll(keywords[language]!);
    if (builtins.containsKey(language)) allWords.addAll(builtins[language]!);
    if (snippets.containsKey(language)) allWords.addAll(snippets[language]!);

    if (prefix.isEmpty) return allWords.toList()..sort();

    final lowerPrefix = prefix.toLowerCase();
    final matches = allWords.where((w) => w.toLowerCase().startsWith(lowerPrefix)).toList();
    matches.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      if (aLower == lowerPrefix) return -1;
      if (bLower == lowerPrefix) return 1;
      if (aLower.startsWith(lowerPrefix) && !bLower.startsWith(lowerPrefix)) return -1;
      if (!aLower.startsWith(lowerPrefix) && bLower.startsWith(lowerPrefix)) return 1;
      return a.compareTo(b);
    });
    return matches;
  }
}
