module Afipws
  class WSFE
    extend Forwardable
    include TypeConversions
    attr_reader :wsaa, :client
    def_delegators :wsaa, :ta, :auth, :cuit

    WSDL = {
      :dev => "http://wswhomo.afip.gov.ar/wsfev1/service.asmx?WSDL",
      :test => Root + '/spec/fixtures/wsfe.wsdl'
    }
    
    def initialize options = {}
      @wsaa = options[:wsaa] || WSAA.new(options.merge(:service => 'wsfe'))
      @client = Client.new WSDL[options[:env] || :test]
    end
    
    def dummy
      @client.fe_dummy
    end
    
    def tipos_comprobantes
      r = @client.fe_param_get_tipos_cbte auth
      x2r get_array(r, :cbte_tipo), :id => :integer, :fch_desde => :date, :fch_hasta => :date
    end
    
    def tipos_documentos
      r = @client.fe_param_get_tipos_doc auth
      x2r get_array(r, :doc_tipo), :id => :integer, :fch_desde => :date, :fch_hasta => :date
    end
    
    def tipos_monedas
      r = @client.fe_param_get_tipos_monedas auth
      x2r get_array(r, :moneda), :fch_desde => :date, :fch_hasta => :date
    end
    
    def tipos_iva
      r = @client.fe_param_get_tipos_iva auth
      x2r get_array(r, :iva_tipo), :id => :integer, :fch_desde => :date, :fch_hasta => :date
    end
    
    def tipos_tributos
      r = @client.fe_param_get_tipos_tributos auth
      x2r get_array(r, :tributo_tipo), :id => :integer, :fch_desde => :date, :fch_hasta => :date      
    end

    # TODO probar una vez q habiliten algunos ptos de venta
    def puntos_venta
      r = @client.fe_param_get_ptos_venta auth
      x2r get_array(r, :pto_venta), :nro => :integer, :fch_baja => :date, :bloqueado => :boolean
    end
    
    def cotizacion moneda_id
      @client.fe_param_get_cotizacion(auth.merge(:mon_id => moneda_id))[:result_get][:mon_cotiz].to_f
    end
    
    def autorizar_comprobantes opciones
      comprobantes = opciones[:comprobantes]
      request = { 'FeCAEReq' => {
        'FeCabReq' => opciones.select_keys(:cbte_tipo, :pto_vta).merge(:cant_reg => comprobantes.size),
        'FeDetReq' => { 
          'FECAEDetRequest' => comprobantes.map do |comprobante|
            comprobante.merge(:cbte_desde => comprobante[:cbte_nro], :cbte_hasta => comprobante[:cbte_nro]).
              select_keys(:concepto, :doc_tipo, :doc_nro, :cbte_desde, 
              :cbte_hasta, :cbte_fch, :imp_total, :imp_tot_conc, :imp_neto, :imp_op_ex, :imp_trib, 
              :mon_id, :mon_cotiz, :iva).merge({ 'ImpIVA' => comprobante[:imp_iva] })
          end
      }}}
      r = @client.fecae_solicitar auth.merge r2x(request, :cbte_fch => :date)
      r = Array.wrap(r[:fe_det_resp][:fecae_det_response]).map do |h| 
        obs = h[:observaciones] ? h[:observaciones][:obs] : nil
        h.select_keys(:cae, :cae_fch_vto).merge(:cbte_nro => h[:cbte_desde]).tap { |h| h.merge!(:observaciones => obs) if obs }
      end
      x2r r, :cae_fch_vto => :date, :cbte_nro => :integer, :code => :integer
    end
    
    def solicitar_caea
      convertir_rta_caea @client.fecaea_solicitar auth.merge(periodo_para_solicitud_caea)
    end
    
    def consultar_caea fecha
      convertir_rta_caea @client.fecaea_consultar auth.merge(periodo_para_consulta_caea(fecha))
    end
    
    def ultimo_comprobante_autorizado opciones
      @client.fe_comp_ultimo_autorizado(auth.merge(opciones))[:cbte_nro].to_i
    end

    def consultar_comprobante opciones
      @client.fe_comp_consultar(auth.merge(opciones))[:result_get]
    end
    
    def cant_max_registros_x_request
      @client.fe_comp_tot_x_request[:reg_x_req].to_i
    end
    
    def periodo_para_solicitud_caea
      if Date.today.day <= 15
        { :orden => 2, :periodo => Date.today.strftime('%Y%m') }
      else
        { :orden => 1, :periodo => Date.today.next_month.strftime('%Y%m') }
      end
    end
    
    def periodo_para_consulta_caea fecha
      orden = fecha.day <= 15 ? 1 : 2
      { :orden => orden, :periodo => fecha.strftime('%Y%m') }
    end
    
    private
    def get_array response, array_element
      Array.wrap response[:result_get][array_element]
    end
    
    def convertir_rta_caea r
      x2r r[:result_get], :fch_tope_inf => :date, :fch_vig_desde => :date, :fch_vig_hasta => :date
    end
  end
end