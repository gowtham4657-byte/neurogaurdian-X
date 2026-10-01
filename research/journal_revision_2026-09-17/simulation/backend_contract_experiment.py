"""Invoke production endpoint functions with isolated provider stubs; never send SOS."""
from pathlib import Path
import asyncio
import importlib.util
import json
import os
import socket
import sys
import types

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT.parents[1]/'neuroguardian_app'
sys.modules['dotenv']=types.SimpleNamespace(load_dotenv=lambda:None)
for key in list(os.environ):
    if any(x in key for x in ['WHATSAPP','TWILIO','SUPERSEND','GOOGLE','NGX_','NTFY']):
        os.environ.pop(key)

def no_network(*args,**kwargs):
    raise RuntimeError('Network is prohibited in this experiment')

socket.create_connection=no_network
spec=importlib.util.spec_from_file_location('tested_server',APP/'backend/emergency_server.py')
server=importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)
server.httpx.AsyncClient=no_network

async def main():
    facilities=[server.Facility(name=f'Synthetic Facility {i}',address='Synthetic test address')
                for i in range(1,4)]
    async def fetch(*a,**kw):return facilities
    server._fetch_google_facilities=fetch
    async def disabled(*a,**kw):return {'channel':'push','sent':False,'provider':'supersend'}
    server._post_supersend=disabled
    rows=[]
    for wa,push in [(True,True),(True,False),(False,True),(False,False)]:
        async def whatsapp(*a,**kw):return [{'channel':'whatsapp','provider':'whatsapp_cloud','sent':wa}]
        async def ntfy(*a,**kw):return {'channel':'push','provider':'ntfy','sent':push}
        server._post_whatsapp=whatsapp;server._post_ntfy=ntfy
        alert=server.EmergencyAlert(event_type='synthetic',reason='offline test',message='NOT SENT',
            location=server.Location(latitude=12.0,longitude=77.0))
        result=await server.emergency_alert(alert,authorization=None)
        assert result['success']==(wa or push)
        assert len(result['facilities'])==3
        rows.append({'wa_provider_accepted':wa,'push_provider_accepted':push,
                     'reported_success':result['success'],'delivery':result['delivery'],
                     'facility_count':len(result['facilities'])})
    failure={'object':'whatsapp_business_account','entry':[{'changes':[{'value':{
        'statuses':[{'id':'SYNTHETIC_ID','status':'failed'}]}}]}]}
    webhook=await server.receive_whatsapp_webhook(failure)
    (ROOT/'results/backend_contract.json').write_text(json.dumps({
        'mode':'direct function calls; transport and providers stubbed; no network',
        'cases':rows,'failed_delivery_webhook_response':webhook,
        'delivery_persistence_present_in_handler':False},indent=2))
    print('4 notification-acceptance combinations and 1 failed-delivery webhook exercised offline.')

asyncio.run(main())
