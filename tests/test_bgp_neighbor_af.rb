#!/usr/bin/env ruby
# RouterBgpNeighborAF Unit Tests
#
# August 2015 Chris Van Heuveln
#
# Copyright (c) 2015 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'ciscotest'
require_relative '../lib/cisco_node_utils/cisco_cmn_utils'
require_relative '../lib/cisco_node_utils/bgp'
require_relative '../lib/cisco_node_utils/bgp_neighbor'
require_relative '../lib/cisco_node_utils/bgp_neighbor_af'

# TestRouterBgpNeighborAF - Minitest for RouterBgpNeighborAF class
class TestRouterBgpNeighborAF < CiscoTestCase
  @@reset_feat = true # rubocop:disable Style/ClassVars

  def setup
    super
    if @@reset_feat
      if platform == :nexus
        config('no feature bgp', 'feature bgp')
        config('no nv overlay evpn', 'nv overlay evpn')
      else
        cleanup_ios_xr
        setup_ios_xr
      end
      @@reset_feat = false # rubocop:disable Style/ClassVars
    else
      if platform == :nexus
        # Just ensure that feature is enabled
        config('feature bgp')
        config('nv overlay evpn')
      end
    end
  end

  def clean_af(af_args, ebgp=true)
    # Most tests only need an address-family cleanup
    asn, vrf, nbr, af = af_args
    dbg = sprintf('[VRF %s NBR %s AF %s]', vrf, nbr, af.join('/'))

    obj_nbr = RouterBgpNeighbor.new(asn, vrf, nbr, true)
    obj_nbr.remote_as = ebgp ? asn + 1 : asn

    obj_af = RouterBgpNeighborAF.new(asn, vrf, nbr, af, true)

    # clean up address-family only
    obj_af.destroy
    obj_af.create
    [obj_af, dbg]
  end

  # One time setup for XR
  # this doesn't support the matrix very well but
  # really only need to test 3 cases (ipv4 uni, l2vpn and a vrf)
  def setup_ios_xr
    return if platform == :nexus
    asn  = 1
    vrf  = 'aa'
    nbr  = '1.1.1.1'
    af   = 'ipv4 unicast'
    vpn  = 'vpnv4 unicast'
    evpn = 'l2vpn evpn'

    # Global requirements
    # route policies
    str1 = 'route-map-in-name'
    str2 = 'route-map-out-name'
    config("route-policy #{str1}", 'end-policy')
    config("route-policy #{str2}", 'end-policy')
    config("route-policy #{str1.reverse}", 'end-policy')
    config("route-policy #{str2.reverse}", 'end-policy')
    config('route-policy foo_bar', 'end-policy')
    config('route-policy baz_inga', 'end-policy')

    # vpn stuff - possibly not needed
    config("vrf #{vrf} address-family #{af}")
    config('rd-set auto', 'end-set')

    # router-id and address-family under the global bgp
    # remote-as under the neighbor
    # VRF statements
    config("router bgp #{asn}")
    config("router bgp #{asn} bgp router-id 1.1.1.1")
    config("router bgp #{asn} neighbor #{nbr} remote-as #{asn}")
    config("router bgp #{asn} address-family #{af}")
    config("router bgp #{asn} address-family #{vpn}")
    config("router bgp #{asn} address-family #{evpn}")
    config("router bgp #{asn} vrf #{vrf} rd auto")
    config("router bgp #{asn} vrf #{vrf} address-family #{af}")
    config("router bgp #{asn} vrf #{vrf} address-family #{evpn}")
    config("router bgp #{asn} vrf #{vrf} neighbor #{nbr} remote-as #{asn}")
    config("router bgp #{asn} vrf #{vrf} neighbor #{nbr} " \
           "address-family #{af}")
    @@node.show('show run')
  end

  def cleanup_ios_xr
    return if platform == :nexus
    config('no router bgp')
    config('no vrf aa address-family ipv4 unicast')
    config('no vrf aa')

    str1 = 'route-map-in-name'
    str2 = 'route-map-out-name'
    config("no route-policy #{str1}")
    config("no route-policy #{str2}")
    config("no route-policy #{str1.reverse}")
    config("no route-policy #{str2.reverse}")
    config('no route-policy foo_bar')
    config('no route-policy baz_inga')
  end

  # def test_foo
  #   af, dbg = clean_af([2, 'red', '1.1.1.1', %w(ipv4 unicast)])
  #   foo(af, dbg)
  # end

  # AF test matrix
  @@matrix = { # rubocop:disable Style/ClassVars
    # 1  => [1, 'default', '10:1::1', %w(ipv4 multicast)], # UNSUPPORTED
    # 2  => [1, 'default', '10:1::1', %w(ipv4 unicast)], # UNSUPPORTED in XR
    # 3  => [1, 'default', '10:1::1', %w(ipv6 multicast)],
    # 4  => [1, 'default', '10:1::1', %w(ipv6 unicast)],
    # 5  => [1, 'default', '1.1.1.1', %w(ipv4 multicast)],
    6  => [1, 'default', '1.1.1.1', %w(ipv4 unicast)],
    # 7  => [1, 'default', '1.1.1.1', %w(ipv6 multicast)],
    # 8  => [1, 'default', '1.1.1.1', %w(ipv6 unicast)],
    # 9 => [1, 'aa', '2.2.2.2', %w(ipv4 multicast)],
    10 => [1, 'aa', '1.1.1.1', %w(ipv4 unicast)],
    # 11 => [1, 'bb', '2.2.2.2', %w(ipv6 multicast)],
    # 12 => [1, 'bb', '2.2.2.2', %w(ipv6 unicast)],
    # 13 => [1, 'cc', '10:1::2', %w(ipv4 multicast)], # UNSUPPORTED
    # 14 => [1, 'cc', '10:1::2', %w(ipv4 unicast)],
    # 15 => [1, 'cc', '10:1::2', %w(ipv6 multicast)],
    # 16 => [1, 'cc', '10:1::2', %w(ipv6 unicast)],
    17 => [1, 'default', '1.1.1.1', %w(l2vpn evpn)],
  }

  # ---------------------------------
  def test_nbr_af_create_destroy
    config('no feature bgp', 'feature bgp') if platform == :nexus
    # Creates
    obj = {}
    @@matrix.each do |k, v|
      asn, vrf, nbr, af = v
      dbg = sprintf('[VRF %s NBR %s AF %s]', vrf, nbr, af)
      obj[k] = RouterBgpNeighborAF.new(asn, vrf, nbr, af, true)
      afs = RouterBgpNeighborAF.afs
      assert(afs[asn][vrf][nbr].key?(af),
             "#{dbg} Failed to create AF")
    end

    # Destroys
    @@matrix.each do |k, v|
      asn, vrf, nbr, af = v
      dbg = sprintf('[VRF %s NBR %s AF %s]', vrf, nbr, af)
      obj[k].destroy
      afs = RouterBgpNeighborAF.afs
      refute(afs[asn][vrf][nbr].key?(af),
             "#{dbg} Failed to destroy AF")
    end
  end

  # ---------------------------------
  def test_nbrs_with_masks
    config('no feature bgp', 'feature bgp')

    # Creates
    obj = {}
    @@matrix.each do |k, v|
      asn, vrf, nbr, af = v
      nbr += (nbr[/:/]) ? '/64' : '/16'
      if platform == :ios_xr
        # XR does not do slash masks and neighbors
        # so make sure to catch the error
        assert_raises(ArgumentError, 'Neighbors do not support /') do
          RouterBgpNeighborAF.new(asn, vrf, nbr, af, true)
        end
        next
      end
      next if platform == :ios_xr
      dbg = sprintf('[VRF %s NBR %s AF %s]', vrf, nbr, af.join('/'))
      obj[k] = RouterBgpNeighborAF.new(asn, vrf, nbr, af, true)
      nbr_munged = Utils.process_network_mask(nbr)
      afs = RouterBgpNeighborAF.afs
      assert(afs[asn][vrf][nbr_munged].key?(af),
             "#{dbg} Failed to create AF")
    end

    # Destroys
    @@matrix.each do |k, v|
      asn, vrf, nbr, af = v
      nbr += (nbr[/:/]) ? '/64' : '/16'
      if platform == :ios_xr
        assert_raises(ArgumentError, 'Neighbors do not support /') do
          RouterBgpNeighborAF.new(asn, vrf, nbr, af, true)
        end
        next
      end
      next if platform == :ios_xr
      dbg = sprintf('[VRF %s NBR %s AF %s]', vrf, nbr, af.join('/'))
      obj[k].destroy
      nbr_munged = Utils.process_network_mask(nbr)
      afs = RouterBgpNeighborAF.afs
      refute(afs[asn][vrf][nbr_munged].key?(af),
             "#{dbg} Failed to destroy AF")
    end
    @@reset_feat = true # rubocop:disable Style/ClassVars
  end

  # ---------------------------------
  def test_props_bool
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      props_bool(af, dbg)
    end
  end

  def props_bool(af, dbg)
    # These properties have simple boolean states. As such we can use a common
    # set of tests to validate each property.
    # Common to both XR and nexus
    props = [
      :as_override,
      :next_hop_self,
    ]

    if platform == :nexus
      props << :next_hop_third_party
      props << :suppress_inactive
      props = [:disable_peer_as_check] if dbg.include?('l2vpn/evpn')
    end

    # Call setter to false, then validate with getter
    props.each { |k| af.send("#{k}=", false) }
    props.each do |k|
      refute(af.send(k), "Test 1. #{dbg} [#{k}=] did not set false")
    end

    # Call setter to true, then validate with getter
    props.each { |k| af.send("#{k}=", true) }
    props.each do |k|
      assert(af.send(k), "Test 2. #{dbg} [#{k}=] did not set true")
    end

    # Set to default and validate
    def_val = {}
    props.each { |k| def_val[k] = af.send("default_#{k}") }
    props.each { |k| af.send("#{k}=", def_val[k]) }
    props.each do |k|
      assert_equal(def_val[k], af.send(k),
                   "Test 3. #{dbg} [#{k}=] did not set to default")
    end
  end

  # ---------------------------------
  def test_props_string
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      props_string(af, dbg)
    end
  end

  def props_string(af, dbg)
    if platform == :nexus
      props = {
        filter_list_in:  'filt-in-name',
        filter_list_out: 'filt-out-name',
        prefix_list_in:  'pref-in-name',
        prefix_list_out: 'pref-out-name',
        route_map_in:    'route-map-in-name',
        route_map_out:   'route-map-out-name',
        unsuppress_map:  'unsupp-map-name',
      }
      props.delete(:unsuppress_map) if dbg.include?('l2vpn/evpn')
    else
      props = {
        route_map_in:  'route-map-in-name',
        route_map_out: 'route-map-out-name',
      }
    end

    props.each do |k, v|
      # Call setter.
      af.send("#{k}=", v)

      # Validate with getter
      assert_equal(v, af.send(k),
                   "Test 1. #{dbg} [#{k}=] did not set string '#{v}'")

      af.send("#{k}=", v.reverse!)
      assert_equal(v, af.send(k),
                   "Test 2. #{dbg} [#{k}=] did not set string '#{v}'")

      # Set to default
      af.send("#{k}=", af.send("default_#{k}"))
      assert_empty(af.send(k),
                   "Test 3. #{dbg} [#{k}=] did not set default [default_#{k}]")
    end
  end

  # ---------------------------------
  # tri-state properties:
  #   additional_paths_receive
  #   additional_paths_send
  #   soft_reconfiguration_in
  def test_tri_states
    platform == :nexus ? tri_states_nexus : tri_states_ios_xr
  end

  def tri_states_ios_xr
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      %w(additional_paths_receive additional_paths_send).each do |k|
        [:enable, :disable, :inherit, 'enable', 'disable', 'inherit'
        ].each do |val|
          assert_raises(UnsupportedError,
                        "This feature #{k}, #{val} is not supported}") do
            af.send("#{k}=", val)
          end
        end
      end

      %w(soft_reconfiguration_in).each do |k|
        [:enable, :always, :inherit, 'enable', 'always', 'inherit',
         af.send("default_#{k}")
        ].each do |val|
          af.send("#{k}=", val)
          assert_equal(val.to_sym, af.send(k), "#{dbg} Error: #{k}")
        end
      end
    end
  end

  def tri_states_nexus
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      unless dbg.include?('l2vpn/evpn')
        %w(additional_paths_receive additional_paths_send).each do |k|
          [:enable, :disable, :inherit, 'enable', 'disable', 'inherit',
           af.send("default_#{k}")
          ].each do |val|
            af.send("#{k}=", val)
            assert_equal(val.to_sym, af.send(k), "#{dbg} Error: #{k}")
          end
        end
      end

      %w(soft_reconfiguration_in).each do |k|
        [:enable, :always, :inherit, 'enable', 'always', 'inherit',
         af.send("default_#{k}")
        ].each do |val|
          af.send("#{k}=", val)
          assert_equal(val.to_sym, af.send(k), "#{dbg} Error: #{k}")
        end
      end
    end
  end

  # ---------------------------------
  def test_advertise_map
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      next if dbg.include?('l2vpn/evpn')
      advertise_map(af, dbg)
    end
  end

  def advertise_map(af, dbg)
    %w(advertise_map_exist advertise_map_non_exist).each do |k|
      v = %w(foo bar)
      if platform == :ios_xr
        assert_raises(UnsupportedError) do
          af.send("#{k}=", v)
        end
        break
      end
      af.send("#{k}=", v)
      assert_equal(v, af.send(k),
                   "Test 1. #{dbg} [#{k}=] did not set strings '#{v}'")

      # Change to new strings
      v = %w(baz inga)
      af.send("#{k}=", v)
      assert_equal(v, af.send(k),
                   "Test 2. #{dbg} [#{k}=] did not set strings '#{v}'")

      # Set to default
      af.send("#{k}=", af.send("default_#{k}"))
      assert_empty(af.send(k),
                   "Test 3. #{dbg} [#{k}] did not set to default " \
                   "'[default_#{k}]'")
    end
  end

  # ---------------------------------
  def test_allowas_in
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      allowas_in(af, dbg)
    end
  end

  def allowas_in(af, dbg)
    af.allowas_in_set(true)
    assert(af.allowas_in,
           "Test 1. #{dbg} Failed to set state to True")

    # Test true with value
    af.allowas_in_set(true, 5)
    assert_equal(5, af.allowas_in_max,
                 "Test 2. #{dbg} Failed to set True with Value")

    # Test false with value
    af.allowas_in_set(false)
    refute(af.allowas_in,
           "Test 3. #{dbg} Failed to set state to False")

    # Test true with value, from false
    af.allowas_in_set(true, 4)
    assert_equal(4, af.allowas_in_max,
                 "Test 4. #{dbg} Failed to set True with Value, " \
                 'from false state')

    # Test default_state
    af.allowas_in_set(af.default_allowas_in)
    refute(af.allowas_in,
           "Test 5. #{dbg} Failed to set state to default")

    # Test true with value set to default
    af.allowas_in_set(true, af.default_allowas_in_max)
    assert_equal(af.default_allowas_in_max, af.allowas_in_max,
                 "Test 6. #{dbg} Failed to set True with default Value")
  end

  # ---------------------------------
  def test_default_originate
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      next if dbg.include?('l2vpn/evpn')
      default_originate(af, dbg)
    end
  end

  def default_originate(af, dbg)
    # Test basic true
    if platform == :ios_xr
      # XR does not support a default route-policy
      assert_raises(ArgumentError) do
        af.default_originate_set(true)
      end
    else
      af.default_originate_set(true)
      assert(af.default_originate,
             "Test 1. #{dbg} Failed to set state to True")
    end
    # Test true with route-map
    af.default_originate_set(true, 'foo_bar')
    assert_equal('foo_bar', af.default_originate_route_map,
                 "Test 2. #{dbg} Failed to set True with Route-map")

    # Test false with route-map
    if platform == :ios_xr
      # XR does not support a default route-policy
      assert_raises(ArgumentError) do
        af.default_originate_set(false)
      end
    else
      af.default_originate_set(false)
      refute(af.default_originate,
             "Test 3. #{dbg} Failed to set state to False")
    end
    # Test true with route-map, from false
    af.default_originate_set(true, 'baz_inga')
    assert_equal('baz_inga', af.default_originate_route_map,
                 "Test 4. #{dbg} Failed to set True with Route-map, " \
                 'from false state')

    # Test default route-map, from true
    if platform == :ios_xr
      # XR does not support a default route-policy
      assert_raises(ArgumentError) do
        af.default_originate_set(true, af.default_default_originate_route_map)
      end
    else
      af.default_originate_set(true, af.default_default_originate_route_map)
      refute(af.default_originate_route_map,
             "Test 5. #{dbg} Failed to set default route-map from existing")
    end

    # Test default_state
    if platform == :ios_xr
      # XR does not support a default route-policy
      assert_raises(ArgumentError) do
        af.default_originate_set(af.default_default_originate)
      end
    else
      af.default_originate_set(af.default_default_originate)
      refute(af.default_originate,
             "Test 6. #{dbg} Failed to set state to default")
    end
  end

  # ---------------------------------
  def test_max_prefix
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      max_prefix(af, dbg)
      max_prefix_defaults(af, dbg)
    end
  end

  def max_prefix(af, dbg)
    limit = 100
    af.max_prefix_set(limit)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 1. #{dbg} Failed to set limit to '#{limit}'")

    limit = 99
    threshold = 49
    af.max_prefix_set(limit, threshold)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 2a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal(threshold, af.max_prefix_threshold,
                 "Test 2b. #{dbg} Failed to set threshold to '#{threshold}'")

    limit = 98
    threshold = 48
    interval = 28
    af.max_prefix_set(limit, threshold, interval)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 3a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal(threshold, af.max_prefix_threshold,
                 "Test 3b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal(interval, af.max_prefix_interval,
                 "Test 3c. #{dbg} Failed to set interval to '#{interval}'")

    limit = 97
    threshold = nil
    warning = true
    af.max_prefix_set(limit, threshold, warning)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 4a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal((platform == :nexus ? threshold : 75), af.max_prefix_threshold,
                 "Test 4b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal(warning, af.max_prefix_warning,
                 "Test 4c. #{dbg} Failed to set warning to '#{warning}'")

    limit = 96
    threshold = nil
    interval = 26
    af.max_prefix_set(limit, threshold, interval)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 5a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal((platform == :nexus ? threshold : 75), af.max_prefix_threshold,
                 "Test 5b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal(interval, af.max_prefix_interval,
                 "Test 5c. #{dbg} Failed to set interval to '#{interval}'")

    limit = 95
    threshold = 45
    warning = true
    af.max_prefix_set(limit, threshold, warning)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 6a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal(threshold, af.max_prefix_threshold,
                 "Test 6b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal(warning, af.max_prefix_warning,
                 "Test 6c. #{dbg} Failed to set warning to '#{warning}'")

    af.max_prefix_set(af.default_max_prefix_limit)
    refute(af.max_prefix_limit,
           "Test 7. #{dbg} Failed to remove maximum_prefix")
  end

  def max_prefix_defaults(af, dbg)
    limit = 94
    threshold = af.default_max_prefix_threshold
    interval = af.default_max_prefix_interval
    af.max_prefix_set(limit, threshold, interval)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 8a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal((platform == :nexus ? threshold : 75), af.max_prefix_threshold,
                 "Test 8b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal(interval, af.max_prefix_interval,
                 "Test 8c. #{dbg} Failed to set interval to '#{interval}'")

    limit = 93
    threshold = af.default_max_prefix_threshold
    warning = af.default_max_prefix_warning
    af.max_prefix_set(limit, threshold, warning)
    assert_equal(limit, af.max_prefix_limit,
                 "Test 9a. #{dbg} Failed to set limit to '#{limit}'")
    assert_equal((platform == :nexus ? threshold : 75), af.max_prefix_threshold,
                 "Test 9b. #{dbg} Failed to set threshold to '#{threshold}'")
    assert_equal((platform == :nexus ? warning : nil), af.max_prefix_warning,
                 "Test 9c. #{dbg} Failed to set warning to '#{warning}'")

    af.max_prefix_set(nil)
    refute(af.max_prefix_limit,
           "Test 10. #{dbg} Failed to remove maximum_prefix")
  end

  # ---------------------------------
  def test_route_reflector_client
    @@matrix.values.each do |af_args|
      # clean_af needs false since route_reflector_client is ibgp only
      af, dbg = clean_af(af_args, false)
      route_reflector_client(af, dbg)
    end
  end

  def route_reflector_client(af, dbg)
    # iBGP only
    af.route_reflector_client = false
    refute(af.route_reflector_client,
           "Test 1. #{dbg} Did not set false")

    af.route_reflector_client = true
    assert(af.route_reflector_client,
           "Test 2. #{dbg} Did not set true")

    def_val = af.default_route_reflector_client
    af.route_reflector_client = def_val
    assert_equal(def_val, af.route_reflector_client,
                 "Test 3. #{dbg} Did not set to default")
  end

  # ---------------------------------
  def test_send_community
    # iBGP only, do extra cleanup
    config('no feature bgp', 'feature bgp') unless platform == :ios_xr
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      platform == :nexus ? send_comm_nexus(af, dbg) : send_comm_xr(af, dbg)
    end
    @@reset_feat = true # rubocop:disable Style/ClassVars
  end

  def send_comm_nexus(af, dbg)
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 1a. #{dbg} Failed to set '#{v}' from None")
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 1b. #{dbg} Failed to set '#{v}' from 'both'")
    v = 'extended'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 2a. #{dbg} Failed to set '#{v}' from 'both'")
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 2b. #{dbg} Failed to set '#{v}' from 'extended'")
    v = 'standard'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 3a. #{dbg} Failed to set '#{v}' from 'extended'")
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 3b. #{dbg} Failed to set '#{v}' from 'standard'")
    v = 'extended'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 4. #{dbg} Failed to set '#{v}' from 'standard'")

    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 5. #{dbg} Failed to set '#{v}' from 'extended'")
    v = 'standard'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 6. #{dbg} Failed to set '#{v}' from 'both'")
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 7. #{dbg} Failed to set '#{v}' from 'standard'")
    v = 'none'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 8. #{dbg} Failed to remove send-community")

    v = 'both'
    af.send_community = v
    assert_equal('both', af.send_community,
                 "Test 9. #{dbg} Failed to set '#{v}' from None")

    v = af.default_send_community
    af.send_community = af.default_send_community
    assert_equal(v, af.send_community,
                 "Test 10. #{dbg} Failed to set state to default")
  end

  def send_comm_xr(af, dbg)
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 1a. #{dbg} Failed to set '#{v}' from None")
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 1b. #{dbg} Failed to set '#{v}' from None")
    v = 'extended'
    af.send_community = v
    assert_equal('send-extended-community-ebgp', af.send_community,
                 "Test 2a. #{dbg} Failed to set '#{v}' from 'both'")
    af.send_community = v
    assert_equal('send-extended-community-ebgp', af.send_community,
                 "Test 2b. #{dbg} Failed to set '#{v}' from 'extended'")
    v = 'standard'
    af.send_community = v
    # XR it's additive
    assert_equal('both', af.send_community,
                 "Test 3a. #{dbg} Failed to set '#{v}' from 'extended'")
    af.send_community = v
    assert_equal('send-community-ebgp', af.send_community,
                 "Test 3b. #{dbg} Failed to set '#{v}' from 'standard'")
    v = 'extended'
    af.send_community = v
    assert_equal('both', af.send_community,
                 "Test 4. #{dbg} Failed to set '#{v}' from 'standard'")
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 5. #{dbg} Failed to set '#{v}' from 'extended'")
    v = 'standard'
    af.send_community = v
    assert_equal('send-community-ebgp', af.send_community,
                 "Test 6. #{dbg} Failed to set '#{v}' from 'both'")
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 7. #{dbg} Failed to set '#{v}' from 'standard'")
    v = 'none'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 8. #{dbg} Failed to remove send-community")
    v = 'both'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 9. #{dbg} Failed to set '#{v}' from None")

    # Add in a test to reverse the order in which extended and
    # standard are configured
    v = 'none'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 9. #{dbg} Failed to remove send-community")
    v = 'extended'
    af.send_community = v
    assert_equal('send-extended-community-ebgp', af.send_community,
                 "Test 9.1 #{dbg} Failed to set '#{v}' from 'none'")
    v = 'standard'
    af.send_community = v
    # XR it's additive
    assert_equal('both', af.send_community,
                 "Test 9.2. #{dbg} Failed to add '#{v}' to 'extended'")
    v = 'none'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 9.3. #{dbg} Failed to remove send-community")
    v = 'standard'
    af.send_community = v
    # XR it's additive
    assert_equal('send-community-ebgp', af.send_community,
                 "Test 9.4. #{dbg} Failed to set '#{v}' from 'none'")
    v = 'extended'
    af.send_community = v
    assert_equal('both', af.send_community,
                 "Test 9.5 #{dbg} Failed to add '#{v}' from 'standard'")
    v = 'none'
    af.send_community = v
    assert_equal(v, af.send_community,
                 "Test 9.6. #{dbg} Failed to remove send-community")
    v = af.default_send_community
    af.send_community = af.default_send_community
    assert_equal(v, af.send_community,
                 "Test 10. #{dbg} Failed to set state to default")
  end

  # ---------------------------------
  def test_soo
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      soo(af, dbg)
    end
  end

  def soo(af, dbg)
    val = '1.1.1.1:1'

    if platform == :ios_xr
      assert_raises(Cisco::UnsupportedError) do
        af.soo = val
      end
    else
      if dbg.include?('default')
        str = "Test 1. #{dbg}[soo=] did not raise CliError"
        assert_raises(CliError, str) do
          af.soo = val
        end
        # SOO is only allowed in non-default VRF
        return
      end
    end

    if platform == :nexus
      # Set initial
      af.soo = val
      assert_equal(val, af.soo,
                   "Test 2. #{dbg} Failed to set '#{val}'")

      # Change to new string
      val = '2:2'
      af.soo = val
      assert_equal(val, af.soo,
                   "Test 3. #{dbg} Failed to change to '#{val}'")

      # Set to default
      val = af.default_soo
      af.soo = val
      assert_empty(af.soo,
                   "Test 4. #{dbg} Failed to set default '#{val}'")
    else
      assert_raises(Cisco::UnsupportedError) do
        af.soo = val
      end
    end
  end

  # --------------------------------
  def test_weight
    @@matrix.values.each do |af_args|
      af, dbg = clean_af(af_args)
      weight(af, dbg) unless dbg.include?('l2vpn/evpn') && platform == :nexus
    end
  end

  def weight(af, dbg)
    af.weight = 22
    assert_equal(22, af.weight, "Test 1. #{dbg} Failed to set weight")

    # Seems odd to set an int to false - but normally there's a default value
    # of some kind but in bgp weight is ignored unless configured. 0 is not
    # acceptable as is nvgens.
    af.weight = false
    assert_equal(nil, af.weight, "Test 2. #{dbg} Failed to remove weight")
  end
end
