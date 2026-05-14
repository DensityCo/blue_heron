# SPDX-FileCopyrightText: 2026 BlueHeron Contributors
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule BlueHeron.PeripheralTest do
  use ExUnit.Case

  alias BlueHeron.GATT.Server
  alias BlueHeron.GATT.Service
  alias BlueHeron.Peripheral

  setup do
    case Process.whereis(BlueHeron.GATT) do
      nil -> start_supervised!({PropertyTable, name: BlueHeron.GATT})
      _pid -> PropertyTable.put(BlueHeron.GATT, ["profile"], [])
    end

    :ok
  end

  describe "add_services/1" do
    test "appends all services to the profile in a single PropertyTable update" do
      PropertyTable.subscribe(BlueHeron.GATT, ["profile"])

      a = %Service{id: :a, type: 0x2800, characteristics: []}
      b = %Service{id: :b, type: 0x2800, characteristics: []}

      assert :ok = Peripheral.add_services([a, b])

      assert_receive %PropertyTable.Event{
                       table: BlueHeron.GATT,
                       property: ["profile"],
                       value: [^a, ^b]
                     }

      refute_receive %PropertyTable.Event{table: BlueHeron.GATT}, 50
      assert PropertyTable.get(BlueHeron.GATT, ["profile"]) == [a, b]
    end

    test "prepends to existing services" do
      seed = %Service{id: :seed, type: 0x2800, characteristics: []}
      PropertyTable.put(BlueHeron.GATT, ["profile"], [seed])

      new = %Service{id: :new, type: 0x2800, characteristics: []}
      assert :ok = Peripheral.add_services([new])

      assert PropertyTable.get(BlueHeron.GATT, ["profile"]) == [new, seed]
    end
  end

  test "current_mtu returns the spec default before the peripheral is ready" do
    state = state(ready?: false)

    assert {:reply, 23, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns the spec default when there is no connection" do
    state = state()

    assert {:reply, 23, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns the spec default before mtu exchange" do
    state = state(connection: %{handle: 1})

    assert {:reply, 23, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  test "current_mtu returns the negotiated mtu" do
    gatt_server = %{Server.init([], 512) | mtu: 247}
    state = state(connection: %{handle: 1}, gatt_server: gatt_server)

    assert {:reply, 247, ^state} = Peripheral.handle_call(:current_mtu, self(), state)
  end

  defp state(overrides \\ []) do
    %{
      ready?: Keyword.get(overrides, :ready?, true),
      connection: Keyword.get(overrides, :connection, nil),
      gatt_server: Keyword.get(overrides, :gatt_server, Server.init([]))
    }
  end
end
