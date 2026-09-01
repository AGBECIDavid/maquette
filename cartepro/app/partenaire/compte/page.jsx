import { Shell } from "../../../components/Shell.jsx";
import { PartnerSpace } from "../../../screens/Partner.jsx";

export const metadata = { title: "Mon compte" };

export default function Page() {
  return <Shell><PartnerSpace section="compte" /></Shell>;
}
