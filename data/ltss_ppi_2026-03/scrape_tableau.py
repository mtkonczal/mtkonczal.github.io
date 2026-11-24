import json, re, requests
from tableauscraper import TableauScraper as TS, utils, api
from tableauscraper.TableauScraper import TableauException

WB, VIEW = "2026-03-LTSSAffordability", "ByState"
HOST = "https://public.tableau.com"

class TS2(TS):
    def loads(self, url=None, params={}):
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "Mozilla/5.0"})
        api.setSession(self)
        r = self.session.post(f"{HOST}/vizql/w/{WB}/v/{VIEW}/startSession/viewing?:embed=y&:showVizHome=no",
                              headers={"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"})
        r.raise_for_status()
        gsh = r.headers.get("global-session-header")
        if gsh: self.session.headers["Global-Session-Header"] = gsh
        self.tableauData = r.json()
        self.host = HOST
        r = api.getTableauData(self)
        dataReg = re.search(r"\d+;({.*})\d+;({.*})", r, re.MULTILINE)
        if not dataReg: raise TableauException(message=r[:2000])
        self.info = json.loads(dataReg.group(1)); self.data = json.loads(dataReg.group(2))
        pm = self.data["secondaryInfo"]["presModelMap"]
        self.dataSegments = pm["dataDictionary"]["presModelHolder"]["genDataDictionaryPresModel"]["dataSegments"]
        self.parameters = utils.getParameterControlInput(self.info)
        self.dashboard = self.info["sheetName"]
        self.filters = utils.getFiltersForAllWorksheet(self.logger, self.data, self.info, rootDashboard=self.dashboard)

if __name__ == "__main__":
    ts = TS2(); ts.loads()
    wb = ts.getWorkbook()
    print("dashboard:", ts.dashboard)
    print("params:", [(p["column"], p["values"][:40], p.get("value")) for p in wb.getParameters()])
    for t in wb.worksheets:
        print("==", t.name, t.data.shape, list(t.data.columns))
        print(t.data.head(4).to_string())
        for f in t.getFilters(): print("  filter:", f["column"], len(f["values"]), f["values"][:15])
