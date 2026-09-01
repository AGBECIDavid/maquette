import { Shell } from "../../components/Shell.jsx";
import { PartnerSpace } from "../../screens/Partner.jsx";

export const metadata = { title: "Tableau de bord partenaire" };

export default function Page() {
  return <Shell><PartnerSpace section="bord" /></Shell>;
}
