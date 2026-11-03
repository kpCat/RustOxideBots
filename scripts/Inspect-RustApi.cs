// .NET 10 file-based metadata reader. Does not load or execute game assemblies.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;
using System.Text.RegularExpressions;

if (args.Length < 2) throw new ArgumentException("assembly.dll type-regex [method-body-regex]");
using var stream = File.OpenRead(args[0]);
using var pe = new PEReader(stream);
var reader = pe.GetMetadataReader();
var provider = new Names();
var filter = new Regex(args[1]);
var ops = typeof(OpCodes).GetFields(BindingFlags.Public | BindingFlags.Static)
    .Where(f => f.FieldType == typeof(OpCode)).Select(f => (OpCode)f.GetValue(null)!)
    .ToDictionary(o => unchecked((ushort)o.Value));
string Token(int token)
{
    try
    {
        var h = MetadataTokens.EntityHandle(token);
        return h.Kind switch
        {
            HandleKind.MethodDefinition => provider.GetTypeFromDefinition(reader, reader.GetMethodDefinition((MethodDefinitionHandle)h).GetDeclaringType(), 0) + "::" + reader.GetString(reader.GetMethodDefinition((MethodDefinitionHandle)h).Name),
            HandleKind.MemberReference => Token(MetadataTokens.GetToken(reader.GetMemberReference((MemberReferenceHandle)h).Parent)) + "::" + reader.GetString(reader.GetMemberReference((MemberReferenceHandle)h).Name),
            HandleKind.FieldDefinition => reader.GetString(reader.GetFieldDefinition((FieldDefinitionHandle)h).Name),
            HandleKind.TypeDefinition => provider.GetTypeFromDefinition(reader, (TypeDefinitionHandle)h, 0),
            HandleKind.TypeReference => provider.GetTypeFromReference(reader, (TypeReferenceHandle)h, 0),
            HandleKind.MethodSpecification => "generic-method",
            _ => h.Kind.ToString()
        };
    }
    catch { return token.ToString("X8"); }
}
foreach (var handle in reader.TypeDefinitions)
{
    var type = reader.GetTypeDefinition(handle);
    var name = provider.GetTypeFromDefinition(reader, handle, 0);
    if (!filter.IsMatch(name)) continue;
    Console.WriteLine($"TYPE {name} : {(type.BaseType.IsNil ? "" : Token(MetadataTokens.GetToken(type.BaseType)))}");
    foreach (var fh in type.GetFields())
    {
        var f = reader.GetFieldDefinition(fh);
        Console.WriteLine($" FIELD {f.Attributes} {f.DecodeSignature(provider, null)} {reader.GetString(f.Name)}");
    }
    foreach (var mh in type.GetMethods())
    {
        var m = reader.GetMethodDefinition(mh);
        var mn = reader.GetString(m.Name);
        var sig = m.DecodeSignature(provider, null);
        Console.WriteLine($" METHOD {m.Attributes} {sig.ReturnType} {mn}({string.Join(", ", sig.ParameterTypes)})");
        if (args.Length < 3 || !Regex.IsMatch(mn, args[2]) || m.RelativeVirtualAddress == 0) continue;
        var il = pe.GetMethodBody(m.RelativeVirtualAddress).GetILBytes()!;
        for (int i = 0; i < il.Length;)
        {
            int offset = i;
            ushort key = il[i++];
            if (key == 0xfe) key = (ushort)(0xfe00 | il[i++]);
            var op = ops[key];
            int length = op.OperandType switch
            {
                OperandType.InlineNone => 0,
                OperandType.ShortInlineBrTarget or OperandType.ShortInlineI or OperandType.ShortInlineVar => 1,
                OperandType.InlineVar => 2,
                OperandType.InlineI8 or OperandType.InlineR => 8,
                OperandType.InlineSwitch => 4 + 4 * BitConverter.ToInt32(il, i),
                _ => 4
            };
            string value = length == 0 ? "" : Convert.ToHexString(il.AsSpan(i, length));
            if (op.OperandType is OperandType.InlineField or OperandType.InlineMethod or OperandType.InlineType or OperandType.InlineTok)
                value = Token(BitConverter.ToInt32(il, i));
            if (op.OperandType == OperandType.InlineString)
                value = reader.GetUserString(MetadataTokens.UserStringHandle(BitConverter.ToInt32(il, i) & 0xffffff));
            Console.WriteLine($"  IL_{offset:X4}: {op.Name} {value}");
            i += length;
        }
    }
}

class Names : ISignatureTypeProvider<string, object?>
{
    public string GetArrayType(string t, ArrayShape s) => t + "[]";
    public string GetByReferenceType(string t) => t + "&";
    public string GetFunctionPointerType(MethodSignature<string> s) => "function";
    public string GetGenericInstantiation(string t, System.Collections.Immutable.ImmutableArray<string> a) => t + "<" + string.Join(",", a) + ">";
    public string GetGenericMethodParameter(object? c, int i) => "!!" + i;
    public string GetGenericTypeParameter(object? c, int i) => "!" + i;
    public string GetModifiedType(string m, string t, bool r) => t;
    public string GetPinnedType(string t) => t;
    public string GetPointerType(string t) => t + "*";
    public string GetPrimitiveType(PrimitiveTypeCode c) => c.ToString();
    public string GetSZArrayType(string t) => t + "[]";
    public string GetTypeFromDefinition(MetadataReader r, TypeDefinitionHandle h, byte k)
    {
        var t = r.GetTypeDefinition(h);
        return (t.GetDeclaringType().IsNil ? r.GetString(t.Namespace) : GetTypeFromDefinition(r, t.GetDeclaringType(), k)) + "." + r.GetString(t.Name);
    }
    public string GetTypeFromReference(MetadataReader r, TypeReferenceHandle h, byte k)
    { var t = r.GetTypeReference(h); return r.GetString(t.Namespace) + "." + r.GetString(t.Name); }
    public string GetTypeFromSpecification(MetadataReader r, object? c, TypeSpecificationHandle h, byte k) => r.GetTypeSpecification(h).DecodeSignature(this, c);
}
