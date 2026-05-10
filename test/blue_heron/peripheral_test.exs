# SPDX-FileCopyrightText: 2026 BlueHeron Contributors
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule BlueHeron.PeripheralTest do
  use ExUnit.Case

  alias BlueHeron.GATT.Server
  alias BlueHeron.Peripheral

  test "current_mtu returns setup incomplete before peripheral is ready" do
    state = state(ready?: false, connection: %{handle: 1})

    assert {:reply, {:error, :setup_incomplete}, ^state} =
             Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns no connection when peripheral is ready without a connection" do
    state = state()

    assert {:reply, {:error, :no_connection}, ^state} =
             Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns default mtu before mtu exchange" do
    state = state(connection: %{handle: 1})

    assert {:reply, {:ok, 23}, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns negotiated mtu" do
    gatt_server = %{Server.init([], 512) | mtu: 247}
    state = state(connection: %{handle: 1}, gatt_server: gatt_server)

    assert {:reply, {:ok, 247}, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  defp state(overrides \\ []) do
    %{
      ready?: Keyword.get(overrides, :ready?, true),
      connection: Keyword.get(overrides, :connection, nil),
      gatt_server: Keyword.get(overrides, :gatt_server, Server.init([]))
    }
  end
end
