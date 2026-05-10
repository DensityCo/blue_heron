# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2021 Troels Brødsgaard
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule BlueHeron.ACL do
  @moduledoc """
  > HCI ACL Data packets are used to exchange data between the Host and Controller

  Bluetooth Spec v5.2, vol 4, Part E, 5.4.2
  """
  alias BlueHeron.{ACL, L2Cap}
  require Logger

  defstruct [:handle, :flags, :data]

  def fragment(%ACL{} = acl, max_size) when is_integer(max_size) and max_size > 0 do
    case acl.data |> payload() |> chunks(max_size) do
      [single] ->
        # Fits in one ACL packet — preserve caller's PB flag (typically 0b00).
        [%{acl | data: single}]

      chunks ->
        # Multi-fragment LE PDU. Per BT Core 5.4 Vol 4 Part E §5.4.2:
        #   PB = 0b10  →  first fragment of an L2CAP PDU
        #   PB = 0b01  →  continuation fragment
        # PB = 0b00 is BR/EDR-only and is dropped by LE central host stacks
        # (which is why a multi-fragment notification with PB=00 on the start
        # frame ack's at the controller but never delivers to the GATT client).
        chunks
        |> Enum.with_index()
        |> Enum.map(fn
          {data, 0} -> %{acl | flags: Map.put(acl.flags, :pb, 2), data: data}
          {data, _index} -> %{acl | flags: Map.put(acl.flags, :pb, 1), data: data}
        end)
    end
  end

  def deserialize(
        <<handle::little-12, pb::2, bc::2, length::little-16, acl_data::binary-size(length)>>
      ) do
    data = BlueHeron.L2Cap.deserialize(acl_data)

    %ACL{
      handle: handle,
      flags: %{pb: pb, bc: bc},
      data: data
    }
  end

  def serialize(%ACL{data: %type{} = data} = acl) do
    serialize(%{acl | data: type.serialize(data)})
  end

  def serialize(%ACL{data: data, handle: handle, flags: %{pb: pb, bc: bc}}) do
    length = byte_size(data)
    <<handle::little-12, pb::2, bc::2, length::little-16, data::binary-size(length)>>
  end

  def serialize(binary) when is_binary(binary), do: binary

  defp payload(%L2Cap{} = l2cap), do: L2Cap.serialize(l2cap)
  defp payload(%type{} = data), do: type.serialize(data)
  defp payload(data) when is_binary(data), do: data

  defp chunks(<<>>, _max_size), do: [<<>>]
  defp chunks(payload, max_size) when byte_size(payload) <= max_size, do: [payload]

  defp chunks(payload, max_size) do
    <<chunk::binary-size(max_size), rest::binary>> = payload
    [chunk | chunks(rest, max_size)]
  end
end
