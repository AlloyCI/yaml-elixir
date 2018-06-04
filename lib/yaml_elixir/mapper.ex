defmodule YamlElixir.Mapper do
  def process(nil, options), do: empty_container(options)
  def process(yaml, options) when is_list(yaml), do: Enum.map(yaml, &process(&1, options))

  def process(yaml, options) do
    yaml
    |> _to_map(options)
    |> extract_map(options)
  end

  defp extract_map(nil, options), do: empty_container(options)
  defp extract_map(map, _), do: map

  defp _to_map({:yamerl_doc, document}, options), do: _to_map(document, options)

  defp _to_map({:yamerl_seq, :yamerl_node_seq, _tag, _loc, seq, _n}, options),
    do: Enum.map(seq, &_to_map(&1, options))

  defp _to_map({:yamerl_map, :yamerl_node_map, _tag, _loc, map_tuples}, options),
    do: _tuples_to_map(map_tuples, empty_container(options), options)

  defp _to_map(
         {:yamerl_str, :yamerl_node_str, _tag, _loc, <<?:, _::binary>> = element},
         options
       ),
       do: key_for(element, options)

  defp _to_map({:yamerl_null, :yamerl_node_null, _tag, _loc}, _options), do: nil
  defp _to_map({_yamler_element, _yamler_node_element, _tag, _loc, elem}, _options), do: elem

  defp _tuples_to_map([], map, _options), do: map

  defp _tuples_to_map([{key, val} | rest], map, options) do
    case key do
      {:yamerl_seq, :yamerl_node_seq, _tag, _log, _seq, _n} ->
        temp_map = new_map(%{}, _to_map(key, options), _to_map(val, options))

        _tuples_to_map(
          rest,
          Map.merge(map, temp_map, &map_merge/3),
          options
        )

      {_yamler_element, _yamler_node_element, _tag, _log, name} ->
        temp_map = new_map(%{}, key_for(name, options), _to_map(val, options))

        _tuples_to_map(
          rest,
          Map.merge(map, temp_map, &map_merge/3),
          options
        )
    end
  end

  defp key_for(<<?:, name::binary>> = original_name, options) do
    options
    |> Keyword.get(:atoms)
    |> maybe_atom(name, original_name)
  end

  defp key_for(name, _options), do: name

  defp maybe_atom(true, name, _original_name), do: String.to_atom(name)
  defp maybe_atom(_, _name, original_name), do: original_name

  defp empty_container(options) do
    with true <- Keyword.get(options, :maps_as_keywords) do
      []
    else
      _ -> %{}
    end
  end

  defp map_merge(_k, v1, v2) when is_map(v1) and is_map(v2) do
    Map.merge(v1, v2)
  end

  defp map_merge(_k, _v1, v2), do: v2

  defp new_map(map, "<<", map2) do
    Map.merge(map, map2, &map_merge/3)
  end

  defp new_map(map, key, map2) do
    Map.put_new(map, key, map2)
  end
end
