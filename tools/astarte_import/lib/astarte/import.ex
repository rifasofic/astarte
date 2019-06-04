#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Import do
  defmodule State do
    defstruct [
      :device_id,
      :interface,
      :path,
      :reception_timestamp,
      :got_interface_fun,
      :got_path_fun,
      :got_data_fun,
      :data
    ]
  end

  def parse(xml, opts \\ []) do
    initial_data = Keyword.get(opts, :data)
    continuation_fun = Keyword.get(opts, :continuation_fun, :undefined)
    got_interface_fun = Keyword.get(opts, :got_interface_fun)
    got_data_fun = Keyword.get(opts, :got_data_fun)
    got_path_fun = Keyword.get(opts, :got_path_fun)

    state = %State{
      data: initial_data,
      got_interface_fun: got_interface_fun,
      got_path_fun: got_path_fun,
      got_data_fun: got_data_fun
    }

    xmerl_opts = [event_fun: &xml_event/3, continuation_fun: continuation_fun, event_state: state]

    {:ok, state, _tail} = :xmerl_sax_parser.stream(xml, xmerl_opts)

    state.data
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'astarte'}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'devices'}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'device'}, attributes}, _loc, state) do
    {:ok, device_id} = fetch_attribute(attributes, 'device_id')

    %State{state | device_id: device_id}
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, 'interfaces'}, _attributes},
         _loc,
         state
       ) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'interface'}, attributes}, _loc, state) do
    with {:ok, name} <- fetch_attribute(attributes, 'name'),
         {:ok, major_string} <- fetch_attribute(attributes, 'major_version'),
         {major, ""} <- Integer.parse(major_string),
         {:ok, minor_string} <- fetch_attribute(attributes, 'minor_version'),
         {minor, ""} <- Integer.parse(minor_string) do
      state = %State{state | interface: {name, major, minor}}

      case state do
        %State{got_interface_fun: nil} ->
          state

        %State{got_interface_fun: got_interface_fun} ->
          got_interface_fun.(state, name, major, minor)
      end
    else
      _any ->
        throw({:error, :invalid_interface})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'values'}, attributes}, _loc, state) do
    {:ok, path} = fetch_attribute(attributes, 'path')

    state = %State{state | path: path}

    case state do
      %State{got_path_fun: nil} ->
        state

      %State{got_path_fun: got_path_fun} ->
        got_path_fun.(state, path)
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'value'}, attributes}, _loc, state) do
    {:ok, reception_timestamp} = fetch_attribute(attributes, 'reception_timestamp')
    {:ok, datetime, 0} = DateTime.from_iso8601(reception_timestamp)

    %State{state | reception_timestamp: datetime}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'value'}}, _loc, state) do
    %State{state | reception_timestamp: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'values'}}, _loc, state) do
    %State{state | path: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'interface'}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'interfaces'}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'device'}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'devices'}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'astarte'}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:characters, chars}, _loc, %State{got_data_fun: got_data_fun} = state) do
    got_data_fun.(state, chars)
  end

  defp xml_event({:ignorableWhitespace, _whitespace}, _location, state) do
    state
  end

  defp xml_event(:startDocument, _location, state) do
    state
  end

  defp xml_event(:endDocument, _location, state) do
    state
  end

  defp fetch_attribute(attributes, attribute_name) do
    attribute_value =
      Enum.find_value(attributes, fn
        {_uri, _prefix, ^attribute_name, attribute_value} ->
          attribute_value

        _ ->
          false
      end)

    if attribute_value do
      {:ok, to_string(attribute_value)}
    else
      {:error, {:missing_attribute, attribute_name}}
    end
  end
end
