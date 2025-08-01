#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		else:
			# Convert to big endian
			var slice: PackedByteArray = bytes.slice(index, index + count)
			slice.reverse()
			return slice

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10: # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class GameState:
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 0, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		var __players_default: Array[GameState.PlayerProto] = []
		__players = PBField.new("players", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __players_default)
		service = PBServiceField.new()
		service.field = __players
		service.func_ref = Callable(self, "add_players")
		data[__players.tag] = service
		
		var __projectiles_default: Array[GameState.ProjectileProto] = []
		__projectiles = PBField.new("projectiles", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __projectiles_default)
		service = PBServiceField.new()
		service.field = __projectiles
		service.func_ref = Callable(self, "add_projectiles")
		data[__projectiles.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[0].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __players: PBField
	func get_players() -> Array[GameState.PlayerProto]:
		return __players.value
	func clear_players() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__players.value.clear()
	func add_players() -> GameState.PlayerProto:
		var element = GameState.PlayerProto.new()
		__players.value.append(element)
		return element
	
	var __projectiles: PBField
	func get_projectiles() -> Array[GameState.ProjectileProto]:
		return __projectiles.value
	func clear_projectiles() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__projectiles.value.clear()
	func add_projectiles() -> GameState.ProjectileProto:
		var element = GameState.ProjectileProto.new()
		__projectiles.value.append(element)
		return element
	
	class PlayerProto:
		func _init():
			var service
			
			__id = PBField.new("id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 0, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __id
			data[__id.tag] = service
			
			__position_x = PBField.new("position_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_x
			data[__position_x.tag] = service
			
			__position_y = PBField.new("position_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_y
			data[__position_y.tag] = service
			
			__position_z = PBField.new("position_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_z
			data[__position_z.tag] = service
			
			__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __rotation_y
			data[__rotation_y.tag] = service
			
			__state = PBField.new("state", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
			service = PBServiceField.new()
			service.field = __state
			data[__state.tag] = service
			
			__health = PBField.new("health", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __health
			data[__health.tag] = service
			
			__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
			service = PBServiceField.new()
			service.field = __username
			data[__username.tag] = service
			
		var data = {}
		
		var __id: PBField
		func has_id() -> bool:
			if __id.value != null:
				return true
			return false
		func get_id() -> int:
			return __id.value
		func clear_id() -> void:
			data[0].state = PB_SERVICE_STATE.UNFILLED
			__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_id(value : int) -> void:
			__id.value = value
		
		var __position_x: PBField
		func has_position_x() -> bool:
			if __position_x.value != null:
				return true
			return false
		func get_position_x() -> float:
			return __position_x.value
		func clear_position_x() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__position_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_x(value : float) -> void:
			__position_x.value = value
		
		var __position_y: PBField
		func has_position_y() -> bool:
			if __position_y.value != null:
				return true
			return false
		func get_position_y() -> float:
			return __position_y.value
		func clear_position_y() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__position_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_y(value : float) -> void:
			__position_y.value = value
		
		var __position_z: PBField
		func has_position_z() -> bool:
			if __position_z.value != null:
				return true
			return false
		func get_position_z() -> float:
			return __position_z.value
		func clear_position_z() -> void:
			data[3].state = PB_SERVICE_STATE.UNFILLED
			__position_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_z(value : float) -> void:
			__position_z.value = value
		
		var __rotation_y: PBField
		func has_rotation_y() -> bool:
			if __rotation_y.value != null:
				return true
			return false
		func get_rotation_y() -> float:
			return __rotation_y.value
		func clear_rotation_y() -> void:
			data[4].state = PB_SERVICE_STATE.UNFILLED
			__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_rotation_y(value : float) -> void:
			__rotation_y.value = value
		
		var __state: PBField
		func has_state() -> bool:
			if __state.value != null:
				return true
			return false
		func get_state():
			return __state.value
		func clear_state() -> void:
			data[5].state = PB_SERVICE_STATE.UNFILLED
			__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
		func set_state(value) -> void:
			__state.value = value
		
		var __health: PBField
		func has_health() -> bool:
			if __health.value != null:
				return true
			return false
		func get_health() -> int:
			return __health.value
		func clear_health() -> void:
			data[6].state = PB_SERVICE_STATE.UNFILLED
			__health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_health(value : int) -> void:
			__health.value = value
		
		var __username: PBField
		func has_username() -> bool:
			if __username.value != null:
				return true
			return false
		func get_username() -> String:
			return __username.value
		func clear_username() -> void:
			data[7].state = PB_SERVICE_STATE.UNFILLED
			__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
		func set_username(value : String) -> void:
			__username.value = value
		
		enum StateProto {
			IDLE = 0,
			MOVE = 1,
			ATTACK = 2,
			DEAD = 3,
			JUMPING = 4,
			FALLING = 5,
			LANDING = 6
		}
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class ProjectileProto:
		func _init():
			var service
			
			__id = PBField.new("id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 0, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __id
			data[__id.tag] = service
			
			__owner_id = PBField.new("owner_id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __owner_id
			data[__owner_id.tag] = service
			
			__position_x = PBField.new("position_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_x
			data[__position_x.tag] = service
			
			__position_y = PBField.new("position_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_y
			data[__position_y.tag] = service
			
			__position_z = PBField.new("position_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __position_z
			data[__position_z.tag] = service
			
			__velocity_x = PBField.new("velocity_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __velocity_x
			data[__velocity_x.tag] = service
			
			__velocity_y = PBField.new("velocity_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __velocity_y
			data[__velocity_y.tag] = service
			
			__velocity_z = PBField.new("velocity_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = __velocity_z
			data[__velocity_z.tag] = service
			
			__damage = PBField.new("damage", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __damage
			data[__damage.tag] = service
			
		var data = {}
		
		var __id: PBField
		func has_id() -> bool:
			if __id.value != null:
				return true
			return false
		func get_id() -> int:
			return __id.value
		func clear_id() -> void:
			data[0].state = PB_SERVICE_STATE.UNFILLED
			__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_id(value : int) -> void:
			__id.value = value
		
		var __owner_id: PBField
		func has_owner_id() -> bool:
			if __owner_id.value != null:
				return true
			return false
		func get_owner_id() -> int:
			return __owner_id.value
		func clear_owner_id() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__owner_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_owner_id(value : int) -> void:
			__owner_id.value = value
		
		var __position_x: PBField
		func has_position_x() -> bool:
			if __position_x.value != null:
				return true
			return false
		func get_position_x() -> float:
			return __position_x.value
		func clear_position_x() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__position_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_x(value : float) -> void:
			__position_x.value = value
		
		var __position_y: PBField
		func has_position_y() -> bool:
			if __position_y.value != null:
				return true
			return false
		func get_position_y() -> float:
			return __position_y.value
		func clear_position_y() -> void:
			data[3].state = PB_SERVICE_STATE.UNFILLED
			__position_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_y(value : float) -> void:
			__position_y.value = value
		
		var __position_z: PBField
		func has_position_z() -> bool:
			if __position_z.value != null:
				return true
			return false
		func get_position_z() -> float:
			return __position_z.value
		func clear_position_z() -> void:
			data[4].state = PB_SERVICE_STATE.UNFILLED
			__position_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_position_z(value : float) -> void:
			__position_z.value = value
		
		var __velocity_x: PBField
		func has_velocity_x() -> bool:
			if __velocity_x.value != null:
				return true
			return false
		func get_velocity_x() -> float:
			return __velocity_x.value
		func clear_velocity_x() -> void:
			data[5].state = PB_SERVICE_STATE.UNFILLED
			__velocity_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_velocity_x(value : float) -> void:
			__velocity_x.value = value
		
		var __velocity_y: PBField
		func has_velocity_y() -> bool:
			if __velocity_y.value != null:
				return true
			return false
		func get_velocity_y() -> float:
			return __velocity_y.value
		func clear_velocity_y() -> void:
			data[6].state = PB_SERVICE_STATE.UNFILLED
			__velocity_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_velocity_y(value : float) -> void:
			__velocity_y.value = value
		
		var __velocity_z: PBField
		func has_velocity_z() -> bool:
			if __velocity_z.value != null:
				return true
			return false
		func get_velocity_z() -> float:
			return __velocity_z.value
		func clear_velocity_z() -> void:
			data[7].state = PB_SERVICE_STATE.UNFILLED
			__velocity_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_velocity_z(value : float) -> void:
			__velocity_z.value = value
		
		var __damage: PBField
		func has_damage() -> bool:
			if __damage.value != null:
				return true
			return false
		func get_damage() -> int:
			return __damage.value
		func clear_damage() -> void:
			data[8].state = PB_SERVICE_STATE.UNFILLED
			__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_damage(value : int) -> void:
			__damage.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
