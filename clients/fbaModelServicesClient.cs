


namespace KBase.CDMI
{
    class Client
    {
        private JsonRpcClient rpc_client;
        private string url;

        public CDMI_Client(string url )
        {
            this.url = url;
            rpc_client = new JsonRpcClient();
            rpc_client.Url = url;
            rpc_client.RequestEncoding = new UTF8Encoding(false);
        }
       

        public Object genome_to_fbamodel(object in_genome)
        {
            object[] plist = new object[] { in_genome } ;

            Object ret = rpc_client.Invoke("fbaModelServices.genome_to_fbamodel", plist);
            return ret;
        }

        public Object fbamodel_to_sbml(object in_model)
        {
            object[] plist = new object[] { in_model } ;

            Object ret = rpc_client.Invoke("fbaModelServices.fbamodel_to_sbml", plist);
            return ret;
        }

        public Object gapfill_fbamodel(object in_model, object in_formulation, object overwrite, object save)
        {
            object[] plist = new object[] { in_model, in_formulation, overwrite, save } ;

            Object ret = rpc_client.Invoke("fbaModelServices.gapfill_fbamodel", plist);
            return ret;
        }

        public Object runfba(object in_model, object in_formulation, object overwrite, object save)
        {
            object[] plist = new object[] { in_model, in_formulation, overwrite, save } ;

            Object ret = rpc_client.Invoke("fbaModelServices.runfba", plist);
            return ret;
        }

        public Object object_to_html(object inObject)
        {
            object[] plist = new object[] { inObject } ;

            Object ret = rpc_client.Invoke("fbaModelServices.object_to_html", plist);
            return ret;
        }

        public Object gapgen_fbamodel(object in_model, object in_formulation, object overwrite, object save)
        {
            object[] plist = new object[] { in_model, in_formulation, overwrite, save } ;

            Object ret = rpc_client.Invoke("fbaModelServices.gapgen_fbamodel", plist);
            return ret;
        }


    }
